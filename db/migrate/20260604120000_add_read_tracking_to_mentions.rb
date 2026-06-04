class AddReadTrackingToMentions < ActiveRecord::Migration[7.1]
  # Mentions become the single source of truth for the Mentions feature.
  # read_at drives the unread sidebar badge and is reset to NULL on every
  # (re-)mention. message_id/created_by_id record the note that triggered the
  # mention and its author. All nullable; existing rows stay unread (read_at
  # NULL) and self-heal the first time the agent opens the conversation.
  def change
    add_column :mentions, :read_at, :datetime
    add_column :mentions, :message_id, :bigint
    add_column :mentions, :created_by_id, :bigint
    add_index :mentions, [:user_id, :read_at], name: 'index_mentions_on_user_id_and_read_at'
  end
end
