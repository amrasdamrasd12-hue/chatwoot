class CreateSpellCheckEvents < ActiveRecord::Migration[7.1]
  # Eltafouk: per-agent audit log for the pre-send spell-check guard.
  # Each row captures one spell-check API call + the agent's final
  # decision in the modal, so the reports page can break down behaviour
  # by agent (errors caught, corrections accepted, originals sent
  # anyway, drafts cancelled to edit).
  def change
    create_table :spell_check_events do |t|
      t.bigint :account_id, null: false
      t.bigint :user_id
      t.bigint :conversation_id
      t.bigint :inbox_id
      t.string :surface, default: 'dm'
      t.integer :strictness, default: 3
      t.string :model_used
      t.boolean :has_errors, default: false, null: false
      t.integer :errors_count, default: 0
      t.integer :original_length, default: 0
      t.integer :corrected_length, default: 0
      # 'pending' immediately after a has_errors=true check, finalised
      # by the modal callbacks into one of: corrected / sent_original /
      # edited / no_errors_send / unknown.
      t.string :decision, default: 'pending', null: false
      t.timestamps
    end

    add_index :spell_check_events, [:account_id, :created_at]
    add_index :spell_check_events, [:account_id, :user_id, :created_at],
              name: 'idx_spell_check_events_acct_user_time'
    add_index :spell_check_events, [:account_id, :decision]
  end
end
