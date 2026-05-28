class FixFacebookInstagramCommentsInboxFlag < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL.squish
      UPDATE inboxes
         SET is_comment_inbox = TRUE
       WHERE name = 'Facebook & Instagram Comments'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE inboxes
         SET is_comment_inbox = FALSE
       WHERE name = 'Facebook & Instagram Comments'
    SQL
  end
end
