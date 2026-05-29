class Captain::SpellCheckService < Captain::BaseTaskService
  # Optional context for the audit log row created on every call. The
  # controller passes user_id/conversation_id/inbox_id/surface so the
  # reports page can break events down by agent and channel.
  pattr_initialize [
    :account!,
    :content!,
    { user_id: nil, conversation_id: nil, inbox_id: nil, surface: 'dm' }
  ]

  attr_reader :event_id

  # Eltafouk: pre-send spell/grammar guard. Runs on every outgoing send so
  # latency dominates UX. Default `gpt-4.1-nano` (cheapest non-reasoning
  # OpenAI model) handles ~95% of real-world replies; for long messages
  # the admin can opt into `gpt-4.1-mini` via the per-account
  # `long_message_strategy` setting because nano loses focus past ~500
  # characters and starts missing obvious typos.
  NANO_MODEL = 'gpt-4.1-nano'.freeze
  MINI_MODEL = 'gpt-4.1-mini'.freeze
  LONG_MESSAGE_THRESHOLD = 500
  VALID_STRATEGIES = %w[skip nano mini hybrid].freeze
  DEFAULT_STRATEGY = 'skip'.freeze

  # Per-account strictness selector. The Liquid template branches on this
  # integer so each level emits a different rulebook to the model. Default
  # is 3 (middle of the road) — agents can dial up later as confidence
  # grows. Labels live alongside the values so the prompt can quote them.
  STRICTNESS_LABELS = {
    1 => 'سطحي جداً',
    2 => 'سطحي',
    3 => 'متوسط',
    4 => 'دقيق',
    5 => 'صارم',
    6 => 'صارم جداً'
  }.freeze
  DEFAULT_STRICTNESS = 3

  def perform
    stripped = content.to_s.strip
    return empty_result if stripped.empty?

    model_to_use = pick_model(stripped)
    return empty_result if model_to_use.nil?  # strategy: skip

    response = make_api_call(model: model_to_use, messages: messages)
    return response if response.is_a?(Hash) && response[:error]

    result = parse_response(response[:message].to_s)
    record_event(model_to_use, result)
    result.merge(event_id: @event_id)
  end

  private

  def strictness
    raw = account.spell_check_settings.to_h['strictness'].to_i
    raw.between?(1, 6) ? raw : DEFAULT_STRICTNESS
  end

  def strategy
    raw = account.spell_check_settings.to_h['long_message_strategy'].to_s
    VALID_STRATEGIES.include?(raw) ? raw : DEFAULT_STRATEGY
  end

  # Strategy switch — runs once per call so we don't pay LLM cost twice:
  #   skip   → no check at all on long messages, nano on short
  #   nano   → cheap+fast everywhere (loses focus past ~500 chars)
  #   mini   → high quality everywhere (5× cost, ~2× latency)
  #   hybrid → nano under the threshold, mini above it
  # Returns the model name to call, or nil to skip the API call entirely.
  def pick_model(stripped)
    long = stripped.length >= LONG_MESSAGE_THRESHOLD
    case strategy
    when 'skip' then long ? nil : NANO_MODEL
    when 'nano' then NANO_MODEL
    when 'mini' then MINI_MODEL
    when 'hybrid' then long ? MINI_MODEL : NANO_MODEL
    else NANO_MODEL
    end
  end

  def system_prompt
    template = prompt_from_file('spell_check')
    Liquid::Template.parse(template).render(
      'strictness' => strictness,
      'strictness_label' => STRICTNESS_LABELS[strictness]
    )
  end

  def messages
    [
      { role: 'system', content: system_prompt },
      { role: 'user', content: content }
    ]
  end

  # JSON metadata fragments the model occasionally leaks into the
  # user-facing "corrected" string when it loses focus on a long input.
  # Spotting any of these means we shouldn't show that text to the agent.
  JSON_LEAK_RE = /
    "corrected"\s*:|
    "fixes"\s*:|
    "wrong"\s*:|
    "right"\s*:|
    "why"\s*:
  /x

  # The prompt asks for JSON of shape
  #   { "corrected": "...", "fixes": [{ "wrong", "right", "why" }, ...] }
  # nano can fail to honour that on long inputs — typically it starts
  # writing the corrected text as plain prose and only emits a JSON
  # fragment at the tail end. We refuse to render those garbled
  # responses to the agent; treating the message as clean is much safer
  # than surfacing raw JSON in the modal.
  def parse_response(raw)
    parsed = extract_json(raw)
    if parsed.nil? || !parsed.is_a?(Hash) || parsed['corrected'].nil?
      Rails.logger.warn "[spell_check] malformed JSON (len=#{raw.length}): #{raw[0, 120]}"
      return safe_no_errors_result
    end

    corrected = parsed['corrected'].to_s

    if corrected.match?(JSON_LEAK_RE)
      Rails.logger.warn "[spell_check] JSON leaked into corrected text: #{corrected[0, 120]}"
      return safe_no_errors_result
    end

    # If the model claimed fixes but the corrected string is byte-for-
    # byte equivalent to the original (after whitespace normalisation),
    # the fixes are ghosts — the model imagined a problem but didn't
    # actually rewrite anything. Opening a modal in this case shows two
    # identical blocks and confuses the agent ("which letter is wrong?
    # they look the same"). Treat as a clean message.
    if equivalent?(content, corrected)
      Rails.logger.warn '[spell_check] ghost fixes — corrected matches original verbatim'
      return safe_no_errors_result
    end

    fixes = Array(parsed['fixes']).filter_map do |fix|
      next unless fix.is_a?(Hash)

      wrong = fix['wrong'].to_s.strip
      right = fix['right'].to_s.strip
      next if wrong.empty? || right.empty?
      # Drop phantom fixes — the model sometimes reports a "correction"
      # where wrong == right (it picked up an informal word but then
      # decided not to change it). These would render as highlighted
      # pills with no actual diff, which confuses the agent.
      next if normalize(wrong) == normalize(right)

      { wrong: wrong, right: right, why: fix['why'].to_s.strip }
    end

    {
      # Authoritative signal: if the model reported zero real fixes,
      # treat the message as clean even when whitespace/punctuation drifted.
      has_errors: fixes.any?,
      original: content,
      corrected: corrected,
      fixes: fixes
    }
  end

  # Drop-in result for malformed model output. Better to silently pass
  # the message through (the customer gets the original, untouched) than
  # to show the agent a broken modal full of JSON syntax.
  def safe_no_errors_result
    { has_errors: false, original: content, corrected: content, fixes: [] }
  end

  def extract_json(raw)
    cleaned = raw.gsub(/```json\s*|```/, '').strip
    match = cleaned.match(/\{[\s\S]*\}/)
    return nil unless match

    JSON.parse(match[0])
  rescue JSON::ParserError, StandardError
    nil
  end

  def empty_result
    { has_errors: false, original: content, corrected: content, fixes: [] }
  end

  # Log one row per *real* LLM call. Decision starts as "pending" when
  # has_errors=true (the client finalises it after the modal closes), or
  # "no_errors_send" otherwise (no modal will open, the send proceeds).
  # Wrapped in rescue so an audit-log failure can never break a customer
  # reply — we'd rather lose a stat than block an agent.
  def record_event(model_used, result)
    fixes_count = Array(result[:fixes]).size
    decision = result[:has_errors] ? 'pending' : 'no_errors_send'

    event = account.spell_check_events.create!(
      user_id: user_id,
      conversation_id: conversation_id,
      inbox_id: inbox_id,
      surface: surface,
      strictness: strictness,
      model_used: model_used,
      has_errors: result[:has_errors] ? true : false,
      errors_count: fixes_count,
      original_length: content.to_s.length,
      corrected_length: result[:corrected].to_s.length,
      decision: decision
    )
    @event_id = event.id
  rescue StandardError => e
    Rails.logger.warn "[spell_check] event log failed: #{e.message[0, 120]}"
    @event_id = nil
  end

  def equivalent?(a, b)
    normalize(a) == normalize(b)
  end

  def normalize(text)
    text.to_s.gsub(/\s+/, ' ').strip
  end

  def event_name
    'spell_check'
  end
end
