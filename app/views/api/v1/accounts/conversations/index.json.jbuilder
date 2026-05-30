json.data do
  json.meta do
    json.mine_count @conversations_count[:mine_count]
    json.assigned_count @conversations_count[:assigned_count]
    json.unassigned_count @conversations_count[:unassigned_count]
    json.all_count @conversations_count[:all_count]
  end
  json.payload do
    json.array! @conversations do |conversation|
      # Eltafouk: list endpoint uses the slim partial variant. Show /
      # update / filter / create / unread / contacts-conversations all
      # render the full payload (default `slim: false`) so callers that
      # need can_reply / muted / hmac_verified / etc. keep getting them.
      json.partial! 'api/v1/conversations/partials/conversation', formats: [:json], conversation: conversation, slim: true
    end
  end
end
