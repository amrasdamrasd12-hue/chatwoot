class Captain::SpellCheckService < Captain::BaseTaskService
  pattr_initialize [:account!, :content!]

  # Eltafouk: pre-send spell/grammar guard. Runs on every outgoing send, so
  # latency dominates the agent's perceived UX. Picks the fastest available
  # OpenAI model (gpt-4.1-nano, typical ≈300–500 ms) and pairs it with a
  # purpose-built Arabic spell-check prompt (~30 tokens vs the 250-token
  # generic Copilot prompt) so input-processing time stays tiny.
  MODEL = 'gpt-4.1-nano'.freeze

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
