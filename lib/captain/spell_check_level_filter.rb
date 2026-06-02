# Eltafouk: deterministic guardrail over the model's proposed fixes.
# nano routinely ignores the prompt's rules (it "normalises" correct
# greetings like أهلًا — adding OR stripping hamza/tanween — and even
# hallucinates the wrong-word). So we enforce a few invariants on every
# fix it returns and keep only the legitimate ones — the guarantee the
# prompt alone can't give. Invariants only, no per-account levels. Pure
# function: takes the parsed result, returns a filtered result.
module Captain::SpellCheckLevelFilter
  module_function

  HAMZA_FORMS = /[أإآٱءؤئ]/
  TANWEEN_MARKS = /[ً-ٍ]/

  # Drop fixes the model invented (wrong word absent from the original) or
  # that downgrade a correct word, then rebuild the corrected string from
  # only the survivors. Nothing survives → clean: the agent's text passes
  # through untouched and no modal opens.
  def apply(result)
    return result unless result[:has_errors]

    # NFC-normalize the boundary so a DECOMPOSED hamza (ALEF U+0627 + combining
    # U+0654) composes to its precomposed form (أ U+0623) already in HAMZA_FORMS:
    # downgrade?/include? then catch the decomposed strip with no regex changes,
    # and stay consistent if the model and original disagree on the form.
    original = result[:original].to_s.unicode_normalize(:nfc)
    fixes = Array(result[:fixes]).map do |fix|
      fix.merge(wrong: fix[:wrong].to_s.unicode_normalize(:nfc), right: fix[:right].to_s.unicode_normalize(:nfc))
    end
    kept = fixes.filter_map { |fix| keep(fix, original) }
    return clean(original) if kept.empty?

    corrected = rebuild(original, kept)
    # Every surviving fix was unappliable (e.g. wrong matched only via
    # substring but never as a token core), so rebuild changed nothing.
    # Collapse to no-errors instead of opening a no-op modal that would ship
    # the uncorrected text and log a phantom fix.
    return clean(original) if normalize_ws(corrected) == normalize_ws(original)

    { has_errors: true, original: original, corrected: corrected, fixes: kept }
  end

  # Tiny whitespace normalizer mirroring the service's normalize, kept local
  # so the filter stays a self-contained pure function.
  def normalize_ws(text)
    text.to_s.gsub(/\s+/, ' ').strip
  end

  # Returns the fix to keep, or nil to drop it.
  def keep(fix, original)
    return nil unless allowed?(fix, original)
    return nil if fix[:right].to_s == fix[:wrong].to_s

    { wrong: fix[:wrong], right: fix[:right], why: fix[:why] }
  end

  def allowed?(fix, original)
    # Never invent a fix (wrong must appear in the original) and never strip
    # a correct hamza/tanween — stripping a mark is always a downgrade of a
    # correct word, never a legitimate fix. (Adding a missing one is fine.)
    original.include?(fix[:wrong].to_s) && !downgrade?(fix[:wrong], fix[:right])
  end

  # True only when the fix's ESSENTIAL change is stripping a correct
  # hamza/tanween — i.e. the bare letters are unchanged and the sole effect
  # is fewer marks. A genuine letter fix (مكتبه→مكتبة, كميا→كيميا) often
  # incidentally drops a stray mark; we must NOT block those, only pure
  # mark-strips of an otherwise-correct word.
  def downgrade?(wrong, right)
    return false unless Captain::SpellCheckCategorizer.bare_letters(wrong) ==
                        Captain::SpellCheckCategorizer.bare_letters(right)

    mark_count(right, HAMZA_FORMS) < mark_count(wrong, HAMZA_FORMS) ||
      mark_count(right, TANWEEN_MARKS) < mark_count(wrong, TANWEEN_MARKS)
  end

  def mark_count(str, regex)
    str.to_s.scan(regex).size
  end

  # Arabic + Latin punctuation/quotes/brackets glued to a token. Mirrors the
  # Vue layer's ARABIC_PUNCT_RE so "كمياء." / "اهلا،" match a fix whose wrong
  # is the bare word. Anchored to the ends so we only peel surrounding
  # punctuation, never punctuation embedded mid-word.
  EDGE_PUNCT = /\A(?<lead>[،؛؟.,!?"'“”‘’«»…:()\[\]{}]*)(?<core>.*?)(?<trail>[،؛؟.,!?"'“”‘’«»…:()\[\]{}]*)\z/m

  def rebuild(original, fixes)
    result = original
    fixes.each do |fix|
      wrong = fix[:wrong].to_s
      right = fix[:right].to_s

      # Whitespace-preserving token replace, fixing EVERY occurrence so a
      # repeated typo can't survive. A token matches if it equals wrong
      # verbatim (covers fixes whose wrong carries its own punctuation, e.g.
      # a punctuation fix اهلا،→اهلا؟) OR if its core — punctuation peeled
      # off both ends — equals wrong (covers a bare wrong glued to stray
      # punctuation in the text, e.g. كمياء. → keep the trailing period).
      tokens = result.split(/(\s+)/)
      tokens.each_with_index do |token, i|
        if token == wrong
          tokens[i] = right
          next
        end
        m = token.match(EDGE_PUNCT)
        tokens[i] = "#{m[:lead]}#{right}#{m[:trail]}" if m && m[:core] == wrong
      end
      result = tokens.join
    end
    result
  end

  def clean(original)
    { has_errors: false, original: original, corrected: original, fixes: [] }
  end
end
