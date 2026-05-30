# Eltafouk: bulk-preloads the per-conversation metadata that the
# `_conversation` jbuilder partial would otherwise fetch row-by-row.
#
# On a 505-row "غير مقروء" response the legacy partial fires four
# extra queries per conversation (~2,020 round-trips) for last
# message / last non-activity message / unread count / can_reply?.
# That dominates view time at ~5s. Preloading these in four single
# queries up-front cuts it to ~300ms while keeping the JSON output
# byte-identical — the partial falls back to its original lookups
# whenever the RequestStore slots aren't populated, so single-record
# endpoints (show/update/etc.) are untouched.
module ConversationListPreloader
  extend ActiveSupport::Concern

  STORE_LAST_MESSAGE       = :conv_preload_last_message
  STORE_LAST_NON_ACTIVITY  = :conv_preload_last_non_activity
  STORE_UNREAD_COUNTS      = :conv_preload_unread_counts
  STORE_LAST_INCOMING      = :conv_preload_last_incoming
  STORE_AVAILABILITY       = :conv_preload_availability

  # Cap kept in sync with Conversation#unread_incoming_messages
  # (`.last(10).count` → at most 10) so the badge number doesn't
  # jump from a clipped 10 to an actual 47 when this codepath wins.
  UNREAD_COUNT_CAP = 10

  def preload_conversation_list_metadata(conversations)
    convs = Array(conversations)
    ids = convs.map(&:id)
    return if ids.empty?

    account_id = convs.first.account_id

    last_messages = bulk_last_messages(ids)
    Thread.current[STORE_LAST_MESSAGE]      = last_messages
    Thread.current[STORE_LAST_NON_ACTIVITY] = bulk_last_non_activity_messages(ids, last_messages)
    Thread.current[STORE_UNREAD_COUNTS]     = bulk_unread_counts(ids)
    Thread.current[STORE_LAST_INCOMING]     = bulk_last_incoming_messages(ids)
    Thread.current[STORE_AVAILABILITY]      = bulk_availability(account_id)
  end

  def clear_conversation_list_preload
    [STORE_LAST_MESSAGE, STORE_LAST_NON_ACTIVITY, STORE_UNREAD_COUNTS, STORE_LAST_INCOMING, STORE_AVAILABILITY].each do |key|
      Thread.current[key] = nil
    end
  end

  private

  # Latest message per conversation, with the same associations that
  # Message#push_event_data + conversation_push_event_data walk: attachments
  # for the message body, sender for `data[:sender]`, conversation + its
  # contact_inbox for the embedded `data[:conversation]` block. Without
  # these, jbuilder re-fires three N+1 queries per row (sender,
  # conversation, contact_inbox) on the 505-row response.
  def bulk_last_messages(ids)
    latest_ids = Message.where(conversation_id: ids)
                        .select('DISTINCT ON (conversation_id) id')
                        .order('conversation_id, created_at DESC, id DESC')
                        .pluck(:id)
    Message.where(id: latest_ids)
           .includes(:sender, { conversation: :contact_inbox }, { attachments: { file_attachment: [:blob] } })
           .index_by(&:conversation_id)
  end

  # Latest non-activity message per conversation. Mirrors
  # `messages.non_activity_messages.first` (the scope reorders by
  # created_at DESC then `.first` returns the latest).
  #
  # Eltafouk: in the very common case the latest message overall
  # IS non-activity, we already have it loaded in `last_messages_map`
  # (with sender/conversation/attachments preloaded). Reuse it and
  # only fall back to a DB query for the conversations whose tail is
  # an activity record — typically a small minority. This cuts the
  # second-heaviest preload query by ~90% on healthy data plus
  # eliminates a second round of sender/contact_inbox N+1 in
  # push_event_data when the partial later serializes the result.
  def bulk_last_non_activity_messages(ids, last_messages_map = {})
    activity_type = Message.message_types[:activity]

    result = {}
    needs_query = []
    ids.each do |conv_id|
      last = last_messages_map[conv_id]
      if last && last.message_type_before_type_cast != activity_type
        result[conv_id] = last
      else
        needs_query << conv_id
      end
    end

    return result if needs_query.empty?

    latest_ids = Message.where(conversation_id: needs_query)
                        .where.not(message_type: activity_type)
                        .select('DISTINCT ON (conversation_id) id')
                        .order('conversation_id, created_at DESC, id DESC')
                        .pluck(:id)
    extras = Message.where(id: latest_ids)
                    .includes(:sender, { conversation: :contact_inbox }, { attachments: { file_attachment: [:blob] } })
                    .index_by(&:conversation_id)
    result.merge(extras)
  end

  # Latest incoming message per conversation. MessageWindowService reads
  # this to decide can_reply? for time-windowed channels (WhatsApp 24h etc.).
  def bulk_last_incoming_messages(ids)
    incoming_type = Message.message_types[:incoming]
    latest_ids = Message.where(conversation_id: ids, message_type: incoming_type)
                        .select('DISTINCT ON (conversation_id) id')
                        .order('conversation_id, created_at DESC, id DESC')
                        .pluck(:id)
    Message.where(id: latest_ids).index_by(&:conversation_id)
  end

  # Eltafouk: contact availability (online?) and user availability
  # (online/offline/busy/etc.) are each looked up via a separate Redis
  # ZSCORE per row in `AvailabilityStatusable`. On a 505-row list that's
  # ~1000 sequential Redis round-trips. `OnlineStatusTracker` already
  # ships bulk helpers: one ZRANGEBYSCORE for the contact set and one
  # ZRANGEBYSCORE + HMGET for user statuses. Cache both as a Set / Hash
  # for the partial to consult.
  def bulk_availability(account_id)
    return nil if account_id.blank?

    {
      contact_ids: ::OnlineStatusTracker.get_available_contact_ids(account_id).to_set,
      users: ::OnlineStatusTracker.get_available_users(account_id)
    }
  rescue StandardError => e
    Rails.logger.warn("[preload] bulk_availability failed: #{e.class}: #{e.message}")
    nil
  end

  # Incoming-message count newer than agent_last_seen_at, per conversation.
  # JOIN with conversations gives us each row's seen_at without a second
  # round-trip. LEAST(..., 10) preserves the legacy 10-row cap so the
  # badge displays the same number it always did.
  def bulk_unread_counts(ids)
    incoming_type = Message.message_types[:incoming]
    # `.reorder(nil)` strips Message's default `ORDER BY created_at`
    # — Postgres rejects GROUP BY queries that reference a non-grouped
    # column in ORDER BY.
    rows = Message
           .joins('JOIN conversations c ON c.id = messages.conversation_id')
           .where(conversation_id: ids, message_type: incoming_type)
           .where('c.agent_last_seen_at IS NULL OR messages.created_at > c.agent_last_seen_at')
           .reorder(nil)
           .group(:conversation_id)
           .pluck(Arel.sql("messages.conversation_id, LEAST(COUNT(*), #{UNREAD_COUNT_CAP})"))
    rows.to_h
  end
end
