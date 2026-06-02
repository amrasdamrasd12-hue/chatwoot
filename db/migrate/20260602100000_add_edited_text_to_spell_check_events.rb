class AddEditedTextToSpellCheckEvents < ActiveRecord::Migration[7.1]
  # Eltafouk: the agent's FINAL sent text when they pick "تعديل النص"
  # (decision 'edited'). Stored only for edited decisions so the reports
  # page can show what the agent actually changed the message to, versus the
  # model's suggestion. Nullable — every other decision leaves it NULL.
  def change
    add_column :spell_check_events, :edited_text, :text
  end
end
