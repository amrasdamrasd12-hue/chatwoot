# Eltafouk: deterministic Arabic bucket for one wrong→right spell-check
# correction. Lives outside Captain::SpellCheckService so the service
# stays focused on the LLM call/audit flow and this stays independently
# testable. Compares the two tokens letter-by-letter rather than trusting
# the model to self-classify. See [[SpellCheckFix]] for the stored keys.
module Captain::SpellCheckCategorizer
  module_function

  # Combining marks treated as "not letters" when bucketing a fix.
  TASHKEEL_RE = /[ً-ْٰ]/ # harakat + tanween + shadda + sukun + superscript alef
  TANWEEN_RE = /[ً-ٍ]/ # ً ٍ ٌ
  TATWEEL = 'ـ'.freeze

  # Returns the first matching bucket — a fix that is both hamza+letter is
  # rare and lands on its dominant difference.
  def category_for(wrong, right)
    w = wrong.to_s.strip
    r = right.to_s.strip
    return 'other' if w.empty? || r.empty?

    w_bare = strip_tashkeel(w)
    r_bare = strip_tashkeel(r)
    # Letters identical once diacritics/tatweel are stripped → mark diff.
    return mark_category(w, r) if w_bare == r_bare

    letter_category(w_bare, r_bare)
  end

  # The wrong/right differ only in diacritics — classify which mark.
  def mark_category(wrong, right)
    return 'tanween' if right.match?(TANWEEN_RE) != wrong.match?(TANWEEN_RE)
    return 'punctuation' if right.include?(TATWEEL) != wrong.include?(TATWEEL)

    'diacritic'
  end

  # Letters differ — hamza/taa/ya families first, then by length.
  def letter_category(w_bare, r_bare)
    return 'hamza' if normalize_hamza(w_bare) == normalize_hamza(r_bare)
    return 'taa' if normalize_taa(w_bare) == normalize_taa(r_bare)
    return 'ya' if normalize_ya(w_bare) == normalize_ya(r_bare)
    return 'letter_extra' if w_bare.length > r_bare.length
    return 'letter_missing' if w_bare.length < r_bare.length

    'letter_wrong'
  end

  def strip_tashkeel(str)
    str.gsub(TASHKEEL_RE, '').delete(TATWEEL)
  end

  def normalize_hamza(str)
    str.tr('أإآٱ', 'اااا')
  end

  # Fold the taa-marbuta family together so the most common Egyptian
  # ending mistakes (مدرسه/مدرست → مدرسة) all bucket as 'taa'.
  def normalize_taa(str)
    str.tr('ةه', 'تت')
  end

  def normalize_ya(str)
    str.tr('ى', 'ي')
  end
end
