# TODO: Move this into models jbuilder
# Currently the file there is used only for search endpoint.
# Everywhere else we use conversation builder in partials folder

# Eltafouk: `slim: true` switches this partial into the trimmed payload
# used by the conversation-list (index) endpoint. We strip the fields
# ConversationCard.vue + the chat-list filter helpers don't actually
# read, shrink sender/assignee blocks, and emit a slim variant of
# push_event_data for the embedded last message. The detail view
# refetches the full conversation via /conversations/:id/show when the
# row is selected, so dropping these fields here doesn't starve the
# right pane. Vuex mutations (SET_CONVERSATION_CAN_REPLY,
# MUTE_CONVERSATION, CHANGE_CONVERSATION_STATUS, …) keep writing the
# missing keys via their own action paths once the detail loads.
slim = local_assigns.fetch(:slim, false)

json.meta do
  json.sender do
    if slim
      # Slim sender — only the bits ConversationCard renders: avatar +
      # name + the WhatsApp phone-pill + the availability dot helper.
      contact = conversation.contact
      json.id contact.id
      json.name contact.name
      json.thumbnail contact.avatar_url
      json.availability_status contact.availability_status
      json.phone_number contact.phone_number
      json.email contact.email
      json.type 'contact'
    else
      json.partial! 'api/v1/models/contact', formats: [:json], resource: conversation.contact
    end
  end
  json.channel conversation.inbox.try(:channel_type)
  if conversation.assigned_entity.is_a?(AgentBot)
    json.assignee do
      json.partial! 'api/v1/models/agent_bot_slim', formats: [:json], resource: conversation.assigned_entity
    end
    json.assignee_type 'AgentBot'
  elsif conversation.assigned_entity&.account
    json.assignee do
      if slim
        # Slim assignee — id/name + the avatar+availability shown next to
        # the contact name on each row. Full agent payload (email, role,
        # custom_role_id, …) lives on the show endpoint.
        agent = conversation.assigned_entity
        json.id agent.id
        json.name agent.name
        json.available_name agent.available_name
        json.thumbnail agent.avatar_url
        json.availability_status agent.availability_status
      else
        json.partial! 'api/v1/models/agent', formats: [:json], resource: conversation.assigned_entity
      end
    end
    json.assignee_type 'User'
  end
  if conversation.team.present?
    json.team do
      json.partial! 'api/v1/models/team', formats: [:json], resource: conversation.team
    end
  end
  unless slim
    # hmac_verified + source_id power the contact-merge / hmac-warning
    # banner on the conversation header — read only after the row is
    # selected, so the list payload can skip them.
    json.hmac_verified conversation.contact_inbox&.hmac_verified
    json.source_id conversation.contact_inbox&.source_id
  end
end

json.id conversation.display_id
# Eltafouk: when the controller has run ConversationListPreloader the
# Thread.current slot holds the latest message (with attachments + sender +
# conversation.contact_inbox preloaded) in a single bulk query.
# Single-record endpoints (show/update/etc.) never call the preloader,
# so the relation lookup is kept as the fallback.
last_message = (Thread.current[ConversationListPreloader::STORE_LAST_MESSAGE] || {})[conversation.id] ||
               conversation.messages.where(account_id: conversation.account_id)
                                    .includes([{ attachments: [{ file_attachment: [:blob] }] }])
                                    .last
if last_message
  json.messages [slim ? last_message.push_event_data_slim : last_message.push_event_data]
else
  json.messages []
end

unless slim
  # account_id + uuid are never read on the list — they're useful for
  # deep-linking / webhook payloads on the detail endpoint.
  json.account_id conversation.account_id
  json.uuid conversation.uuid
end
json.additional_attributes conversation.additional_attributes
unless slim
  # *_last_seen_at drive the unread-divider line inside MessagesView,
  # which only ever sees the currently-selected conversation. The list
  # uses `unread_count` (kept below) for the badge.
  json.agent_last_seen_at conversation.agent_last_seen_at.to_i
  json.assignee_last_seen_at conversation.assignee_last_seen_at.to_i
  json.contact_last_seen_at conversation.contact_last_seen_at.to_i
end
# Eltafouk: can_reply must always emit — ReplyBox falls back to
# isPrivate=true / isReplyRestricted=true when undefined, locking the
# composer on non-WhatsApp channels. The preloader primes
# STORE_LAST_INCOMING so MessageWindowService skips its per-row query;
# slim path is a channel-type switch + a date compare (~1ms/row).
preloaded_last_incoming = (Thread.current[ConversationListPreloader::STORE_LAST_INCOMING] || {})[conversation.id]
json.can_reply Conversations::MessageWindowService.new(conversation, last_incoming_message: preloaded_last_incoming).can_reply?
json.custom_attributes conversation.custom_attributes
json.inbox_id conversation.inbox_id
json.labels conversation.cached_label_list_array
# muted / snoozed_until are tiny columns and are read by ConversationHeader
# / MoreActions immediately on row selection — restoring them to the list
# payload avoids a flash of wrong state. The MUTE/UNMUTE/CHANGE_STATUS
# Vuex mutations still refresh them locally on subsequent acts.
json.muted conversation.muted?
json.snoozed_until conversation.snoozed_until
json.status conversation.status
json.created_at conversation.created_at.to_i
unless slim
  # updated_at is read in UPDATE_CONVERSATION's out-of-order guard for
  # websocket updates — the show endpoint repopulates it before we ever
  # diff updates.
  json.updated_at conversation.updated_at.to_f
end
json.timestamp conversation.last_activity_at.to_i
unless slim
  json.first_reply_created_at conversation.first_reply_created_at.to_i
end
json.unread_count conversation.cached_unread_incoming_count
preloaded_last_non_activity = (Thread.current[ConversationListPreloader::STORE_LAST_NON_ACTIVITY] || {})[conversation.id]
last_non_activity = preloaded_last_non_activity ||
                    conversation.messages.where(account_id: conversation.account_id).non_activity_messages.first
if last_non_activity
  json.last_non_activity_message(slim ? last_non_activity.push_event_data_slim : last_non_activity.push_event_data)
else
  json.last_non_activity_message nil
end
# Eltafouk: name of whoever last replied to the customer — agent, bot, or an
# automated out-of-office (template) message — shown on each conversation-list
# row so supervisors can tell who last handled the chat without opening it.
# Bulk-preloaded to avoid an N+1; single-record endpoints fall back to a lookup.
reply_message_types = Message.message_types.values_at('outgoing', 'template')
preloaded_last_outgoing = (Thread.current[ConversationListPreloader::STORE_LAST_OUTGOING] || {})[conversation.id]
last_outgoing = preloaded_last_outgoing ||
                conversation.messages.where(account_id: conversation.account_id)
                            .where(message_type: reply_message_types, private: false)
                            .reorder(created_at: :desc).first
json.last_reply_agent_name(last_outgoing ? (last_outgoing.sender&.name.presence || 'Bot') : nil)
json.last_activity_at conversation.last_activity_at.to_i
json.priority conversation.priority
unless slim
  # waiting_since powers the waiting-since sort + unattended filter; for
  # unread mode neither runs. sla_policy_id surfaces the SLA badge on the
  # card — acceptable trade-off for the slim list, the show endpoint
  # restores it on selection.
  json.waiting_since conversation.waiting_since.to_i.to_i
  json.sla_policy_id conversation.sla_policy_id
end
# Eltafouk: hide the enterprise SLA blocks from the slim payload — the
# detail/show endpoint still renders them and the card-level SLA badge
# was already dropped above (sla_policy_id).
json.partial! 'enterprise/api/v1/conversations/partials/conversation', conversation: conversation, slim: slim if ChatwootApp.enterprise?
