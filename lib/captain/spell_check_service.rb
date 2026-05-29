class Captain::SpellCheckService < Captain::BaseTaskService
  pattr_initialize [:account!, :content!]

  # Eltafouk: pre-send spell/grammar guard. Runs on every outgoing send so
  # latency dominates UX. gpt-4.1-nano is OpenAI's cheapest non-reasoning
  # model and pairs well with the parameterised Arabic spell_check.liquid
  # prompt — keeping per-call processing time minimal.
  MODEL = 'gpt-4.1-nano'.freeze

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

    response = make_api_call(model: MODEL, messages: messages)
    return response if response.is_a?(Hash) && response[:error]

    parse_response(response[:message].to_s)
  end

  private

  def strictness
    raw = account.spell_check_settings.to_h['strictness'].to_i
    raw.between?(1, 6) ? raw : DEFAULT_STRICTNESS
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

  # The prompt asks for JSON of shape
  #   { "corrected": "...", "fixes": [{ "wrong", "right", "why" }, ...] }
  # but small models occasionally wrap the JSON in code fences or stray
  # prose. We extract the first JSON object found and fall back to a
  # "treat the whole response as plain corrected text" path so a sloppy
  # model response can still drive the modal correctly.
  def parse_response(raw)
    parsed = extract_json(raw)
    if parsed.nil?
      return {
        has_errors: !equivalent?(content, raw),
        original: content,
        corrected: raw,
        fixes: []
      }
    end

    corrected = (parsed['corrected'] || raw).to_s
    fixes = Array(parsed['fixes']).filter_map do |fix|
      next unless fix.is_a?(Hash)

      wrong = fix['wrong'].to_s.strip
      right = fix['right'].to_s.strip
      next if wrong.empty? || right.empty?

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
