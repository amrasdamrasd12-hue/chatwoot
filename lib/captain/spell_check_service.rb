class Captain::SpellCheckService < Captain::BaseTaskService
  pattr_initialize [:account!, :content!]

  # Eltafouk: pre-send spell/grammar guard. Runs on every outgoing send, so
  # latency dominates the agent's perceived UX. Reverted from gpt-5-nano —
  # despite being 50% cheaper on input, it routes through GPT-5's reasoning
  # pipeline and showed 4–8s latencies in production (vs. 0.5–0.9s on
  # gpt-4.1-nano), unacceptable for a per-send guard. Sticking with
  # gpt-4.1-nano: still OpenAI's cheapest non-reasoning model, paired with
  # the tight Arabic spell_check.liquid prompt (~30 tokens) for minimal
  # input-processing time.
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
