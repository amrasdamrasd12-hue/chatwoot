# Eltafouk: deterministic guardrail over the model's proposed fixes.
# nano routinely ignores the prompt's per-level rules (it "normalises"
# correct greetings like أهلًا at level 1, adding OR stripping
# hamza/tanween, and even hallucinates the wrong-word). So we categorise
# every fix it returns and keep only the ones this strictness level
# actually permits — the guarantee the prompt alone can't give. Pure
# function: takes the parsed result + level, returns a filtered result.
module Captain::SpellCheckLevelFilter
  module_function

  # Each fix category is allowed from this strictness upward — mirrors the
  # per-level rules in the spell_check Liquid template. Hamza is scrutinised
  # from level 1 (adding a missing hamza is a common, clear fix); tanween
  # stays pedantic (level 4+).
  CATEGORY_MIN_LEVEL = {
    'letter_missing' => 1, 'letter_extra' => 1, 'letter_wrong' => 1, 'other' => 1,
    'hamza' => 1, 'taa' => 3, 'ya' => 3,
    'tanween' => 4, 'diacritic' => 5, 'punctuation' => 6
  }.freeze

  HAMZA_FORMS = /[أإآٱءؤئ]/
  TANWEEN_MARKS = /[ً-ٍ]/
  # harakat + shadda + sukun + combining maddah/hamza-above/hamza-below
  # (U+0653-0655) + superscript alef. Range stops below TANWEEN_MARKS
  # (U+064B-064D) so the two never overlap.
  DIACRITIC_MARKS = /[َ-ٰٕ]/

  # Drop fixes the model invented (wrong word absent from the original) or
  # that this level forbids, then rebuild the corrected string from only
  # the survivors. Nothing survives → clean: the agent's text passes
  # through untouched and no modal opens.
  def apply(result, level)
    return result unless result[:has_errors]

    original = result[:original].to_s
    kept = Array(result[:fixes]).filter_map { |fix| keep(fix, level, original) }
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

  # Returns the (possibly sanitised) fix to keep, or nil to drop it.
  def keep(fix, level, original)
    return nil unless allowed?(fix, level, original)

    # A hamza fix at level 1 can slip a tanween in alongside it ("اهلا" →
    # "أهلاً"); strip any mark the level doesn't permit so only the
    # allowed part of the change survives.
    right = sanitize(fix[:right], level)
    return nil if right == fix[:wrong].to_s

    { wrong: fix[:wrong], right: right, why: fix[:why] }
  end

  def allowed?(fix, level, original)
    return false unless original.include?(fix[:wrong].to_s)
    # Never strip a correct hamza/tanween — stripping a mark is always a
    # downgrade of a correct word, never a legitimate fix. (Adding a
    # missing one is fine, subject to the level below.)
    return false if downgrade?(fix[:wrong], fix[:right])

    category = Captain::SpellCheckCategorizer.category_for(fix[:wrong], fix[:right])
    level >= CATEGORY_MIN_LEVEL.fetch(category, 1)
  end

  # Remove diacritic marks the level doesn't allow from a corrected word.
  def sanitize(right, level)
    text = right.to_s
    text = text.gsub(TANWEEN_MARKS, '') if level < CATEGORY_MIN_LEVEL.fetch('tanween')
    text = text.gsub(DIACRITIC_MARKS, '') if level < CATEGORY_MIN_LEVEL.fetch('diacritic')
    text
  end

  # True only when the fix's ESSENTIAL change is stripping a correct
  # hamza/tanween — i.e. the bare letters are unchanged and the sole effect
  # is fewer marks. A genuine letter fix (مكتبه→مكتبة, كميا→كيميا) often
  # incidentally drops a stray mark; we must NOT block those even at max
  # strictness, only pure mark-strips of an otherwise-correct word.
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
