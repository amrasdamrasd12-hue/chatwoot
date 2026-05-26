class AddIsCommentInboxToInboxes < ActiveRecord::Migration[7.1]
  def up
    add_column :inboxes, :is_comment_inbox, :boolean, default: false, null: false
    add_index :inboxes, :is_comment_inbox, where: 'is_comment_inbox = true',
                                           name: 'index_inboxes_on_is_comment_inbox_partial'

    # Backfill: the four Facebook/Instagram comment inboxes (eltafouk) that were
    # previously flagged via a hardcoded list in the sidebar. Channel::Api guard
    # so the migration is a safe no-op in environments where those IDs map to
    # something else (e.g. fresh / local DBs).
    execute <<~SQL.squish
      UPDATE inboxes
         SET is_comment_inbox = TRUE
       WHERE id IN (24, 25, 26, 27)
         AND channel_type = 'Channel::Api'
    SQL
  end

  def down
    remove_index :inboxes, name: 'index_inboxes_on_is_comment_inbox_partial'
    remove_column :inboxes, :is_comment_inbox
  end
end
