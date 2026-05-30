class SpellCheckFix < ApplicationRecord
  # Eltafouk: a single correction the spell-check model reported, captured
  # so the per-agent report can show recurring mistakes + category
  # breakdowns instead of a bare error count. See [[SpellCheckEvent]].

  # Deterministic buckets derived from the wrong/right diff in
  # Captain::SpellCheckService#fix_category. Arabic labels live on the
  # frontend; the backend only stores the stable key.
  CATEGORIES = %w[
    hamza tanween taa ya
    letter_missing letter_extra letter_wrong
    diacritic punctuation other
  ].freeze

  belongs_to :account
  belongs_to :spell_check_event
  belongs_to :user, optional: true

  validates :wrong, presence: true
  validates :right, presence: true
  validates :category, inclusion: { in: CATEGORIES }

  scope :in_range, ->(from, to) { where(created_at: from..to) if from && to }

  # Eltafouk: bulk-insert the individual corrections for one spell-check
  # event, categorising each one deterministically. account/user are
  # denormalised off the event so the report can group without a join.
  # Tokens truncated so a runaway word can't bloat a row.
  def self.record_for(event, fixes)
    rows = Array(fixes).filter_map do |fix|
      next unless fix.is_a?(Hash)

      wrong = fix[:wrong].to_s.strip
      right = fix[:right].to_s.strip
      next if wrong.empty? || right.empty?

      {
        account_id: event.account_id,
        spell_check_event_id: event.id,
        user_id: event.user_id,
        wrong: wrong[0, 120],
        right: right[0, 120],
        why: fix[:why].to_s.strip[0, 200],
        category: Captain::SpellCheckCategorizer.category_for(wrong, right),
        created_at: event.created_at
      }
    end
    # rubocop:disable Rails/SkipsModelValidations -- bulk insert of validated, pre-built rows
    insert_all(rows) if rows.any?
    # rubocop:enable Rails/SkipsModelValidations
  end
end
