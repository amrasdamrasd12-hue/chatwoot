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

  HAMZA_FORMS = /[أإآٱ]/
  TANWEEN_MARKS = /[ً-ٍ]/
  DIACRITIC_MARKS = /[َ-ْٰ]/ # harakat + shadda + sukun + superscript alef (no tanween)

  # Drop fixes the model invented (wrong word absent from the original) or
  # that this level forbids, then rebuild the corrected string from only
  # the survivors. Nothing survives → clean: the agent's text passes
  # through untouched and no modal opens.
  def apply(result, level)
    return result unless result[:has_errors]

    original = result[:original].to_s
    kept = Array(result[:fixes]).filter_map { |fix| keep(fix, level, original) }
    return clean(original) if kept.empty?

    { has_errors: true, original: original, corrected: rebuild(original, kept), fixes: kept }
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

  # True when the "fix" removes a hamza or tanween the original had.
  def downgrade?(wrong, right)
    mark_count(right, HAMZA_FORMS) < mark_count(wrong, HAMZA_FORMS) ||
      mark_count(right, TANWEEN_MARKS) < mark_count(wrong, TANWEEN_MARKS)
  end

  def mark_count(str, regex)
    str.to_s.scan(regex).size
  end

  def rebuild(original, fixes)
    fixes.reduce(original) { |text, fix| text.sub(fix[:wrong].to_s, fix[:right].to_s) }
  end

  def clean(original)
    { has_errors: false, original: original, corrected: original, fixes: [] }
  end
end
