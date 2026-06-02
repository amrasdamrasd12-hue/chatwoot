class Captain::SpellCheckService < Captain::BaseTaskService
  # Stateless check — no audit row is written here. The /spell_check call is a
  # typing prefetch that may never lead to a send, so persisting an event per
  # check left orphaned 'draft' rows. The controller now creates the event
  # once at decision time, so this service only runs the LLM and returns the
  # result (plus the model that actually ran, for the controller to persist).
  pattr_initialize [
    :account!,
    :content!
  ]

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
  # Default `nano` so BOTH short and long messages get spell-checked. Prod
  # runs on free Vertex/Gemini, so the old `skip` (no check past 500 chars)
  # left long replies silently unchecked for no cost saving. The `skip`
  # option stays available for accounts that explicitly want it.
  DEFAULT_STRATEGY = 'nano'.freeze

  def perform
    stripped = content.to_s.strip
    return empty_result if stripped.empty?
    # Nothing to spell-check if there are no Arabic letters at all (pure
    # emoji / numbers / links / punctuation) — skip the LLM call entirely.
    return empty_result unless stripped.match?(/\p{Arabic}/)

    model_to_use = pick_model(stripped)
    return empty_result if model_to_use.nil?  # strategy: skip

    response = make_api_call(model: model_to_use, messages: messages)
    return response if response.is_a?(Hash) && response[:error]

    result = Captain::SpellCheckLevelFilter.apply(parse_response(response[:message].to_s))
    # Surface the model that actually ran — when Vertex is active, the requested
    # gpt-* model gets overridden to Gemini. The controller persists this on the
    # event at decision time.
    actual_model = Llm::Config.vertex? ? Llm::Config::VERTEX_MODEL : model_to_use
    result.merge(model_used: actual_model)
  end

  private

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
    strategy_model(strategy, long)
  end

  def strategy_model(mode, long)
    case mode
    when 'skip' then long ? nil : NANO_MODEL
    when 'mini' then MINI_MODEL
    when 'hybrid' then long ? MINI_MODEL : NANO_MODEL
    else NANO_MODEL # 'nano' and any unknown value default to the cheap model
    end
  end

  def system_prompt
    Liquid::Template.parse(prompt_from_file('spell_check')).render
  end

  def messages
    [
      { role: 'system', content: system_prompt },
      { role: 'user', content: content }
    ]
  end

  # The prompt asks the model for ONLY the fixes array — shape
  #   { "fixes": [{ "wrong", "right", "why" }, ...] }
  # — never the full corrected text (echoing it doubled output tokens and
  # the filter rebuilds corrected from fixes anyway). So we only parse and
  # validate fixes here; `corrected` is a placeholder (the original) that
  # SpellCheckLevelFilter.apply replaces with the rebuilt-from-fixes string.
  # Malformed JSON (no parseable object / no fixes key) → fail open: treat
  # the reply as clean rather than block the agent on a garbled response.
  def parse_response(raw)
    parsed = extract_json(raw)
    return safe_no_errors_result unless parsed.is_a?(Hash) && parsed.key?('fixes')

    fixes = build_fixes(parsed['fixes'])

    {
      has_errors: fixes.any?,
      original: content,
      corrected: content, # placeholder; the level filter rebuilds it from fixes
      fixes: fixes
    }
  end

  # Normalise the model's fix list: drop non-hashes, blanks, and phantom
  # fixes where wrong == right (the model flagged a word then decided not
  # to change it — would render a highlighted pill with no actual diff).
  def build_fixes(raw_fixes)
    Array(raw_fixes).filter_map do |fix|
      next unless fix.is_a?(Hash)

      wrong = fix['wrong'].to_s.strip
      right = fix['right'].to_s.strip
      next if wrong.empty? || right.empty?
      next if normalize(wrong) == normalize(right)

      { wrong: wrong, right: right, why: fix['why'].to_s.strip }
    end
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
  rescue StandardError
    nil
  end

  # No LLM ran (empty/non-Arabic content, or strategy: skip), so there is no
  # model to report — carry model_used: nil for a uniform shape so the
  # controller renders the same keys on every path.
  def empty_result
    { has_errors: false, original: content, corrected: content, fixes: [], model_used: nil }
  end

  # Tatweel (U+0640) plus zero-width/RTL marks (U+200B-200F, U+202A-202E):
  # all invisible, so leaving them in would let ghost/clean detection be
  # defeated by a string that looks identical but isn't byte-equal.
  INVISIBLE_MARKS = /[ـ​-‏‪-‮]/

  # Collapse whitespace and drop invisible marks so two visually-identical
  # strings compare equal.
  def normalize(text)
    text.to_s.gsub(INVISIBLE_MARKS, '').gsub(/\s+/, ' ').strip
  end

  def event_name
    'spell_check'
  end
end
