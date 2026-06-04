class Conversations::UserMentionJob < ApplicationJob
  queue_as :default

  # message_id/created_by_id default to nil so jobs enqueued before this deploy
  # (3-arg payload) stay deserializable. read_at is reset to nil on every
  # (re-)mention so the conversation re-surfaces as unread in the sidebar badge.
  def perform(mentioned_user_ids, conversation_id, account_id, message_id = nil, created_by_id = nil)
    mentioned_user_ids.each do |mentioned_user_id|
      mention = Mention.find_or_initialize_by(user_id: mentioned_user_id, conversation_id: conversation_id, account_id: account_id)
      # read_at reset to nil so the (re-)mention re-surfaces as unread in the badge.
      mention.update!(mentioned_at: Time.zone.now, message_id: message_id, created_by_id: created_by_id, read_at: nil)
    end
  end
end
