class Captain::SpellCheckService < Captain::BaseTaskService
  pattr_initialize [:account!, :content!]

  # Eltafouk: pre-send spell/grammar guard. Wraps the existing
  # `fix_spelling_grammar` prompt — same Arabic-aware corrections used by the
  # Copilot "fix" action — but bound to gpt-4.1-mini (≈5× cheaper / 2× faster
  # than the default gpt-4.1) since spell-check runs on every outgoing send.
  # Returns a structured result so the client can short-circuit when the
  # message is already clean and only render the diff modal when it isn't.
  MODEL = 'gpt-4.1-mini'.freeze

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
      { role: 'system', content: prompt_from_file('fix_spelling_grammar') },
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
