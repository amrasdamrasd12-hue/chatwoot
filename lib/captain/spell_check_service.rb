class Captain::SpellCheckService < Captain::BaseTaskService
  pattr_initialize [:account!, :content!]

  # Eltafouk: pre-send spell/grammar guard. Runs on every outgoing send, so
  # latency dominates the agent's perceived UX. gpt-5-nano is the cheapest
  # OpenAI model as of May 2026 ($0.05/$0.40 per Mtok vs gpt-4.1-nano's
  # $0.10/$0.40 — same output price, half the input price) with comparable
  # quality on a constrained spelling/grammar task. Paired with the tight
  # Arabic spell_check.liquid prompt (~30 tokens) so input-processing time
  # stays minimal.
  MODEL = 'gpt-5-nano'.freeze

  def perform
    stripped = content.to_s.strip
    return { has_errors: false, corrected: content, original: content } if stripped.empty?

    response = make_api_call(model: MODEL, messages: messages)
    return response if response.is_a?(Hash) && response[:error]

    corrected = response[:message].to_s
    {
      has_errors: !equivalent?(content, corrected),
      original: content,
      corrected: corrected
    }
  end

  private

  def messages
    [
      { role: 'system', content: prompt_from_file('spell_check') },
      { role: 'user', content: content }
    ]
  end

  # Whitespace-insensitive equality — the model occasionally normalises
  # trailing newlines or collapses double spaces even when no real spelling
  # change happened; treating those as "no error" avoids a popup spam loop.
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
