class CreateSpellCheckFixes < ActiveRecord::Migration[7.1]
  # Eltafouk: one row per individual correction the spell-check model
  # reported (the `fixes` array on a SpellCheckEvent). The parent event
  # only stores the *count* of errors; this table stores *what* they were
  # so the per-agent report can surface recurring mistakes, category
  # breakdowns, and real examples — the data a manager needs to evaluate
  # staff spelling, not just tally it.
  #
  # account_id + user_id are denormalised off the parent event so the
  # report can group by agent without an extra join. Rows are immutable
  # (no updated_at).
  def change
    create_table :spell_check_fixes do |t|
      t.bigint :account_id, null: false
      t.bigint :spell_check_event_id, null: false
      t.bigint :user_id
      t.string :wrong, null: false
      t.string :right, null: false
      t.string :why
      # Deterministic bucket derived in Ruby from the wrong/right diff:
      # hamza / tanween / taa / ya / letter_missing / letter_extra /
      # letter_wrong / diacritic / punctuation / other.
      t.string :category, default: 'other', null: false
      t.datetime :created_at, null: false
    end

    add_index :spell_check_fixes, [:account_id, :user_id, :created_at],
              name: 'idx_spell_check_fixes_acct_user_time'
    add_index :spell_check_fixes, [:account_id, :category]
    add_index :spell_check_fixes, :spell_check_event_id
  end
end
