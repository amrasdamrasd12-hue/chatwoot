class MarketingCommentModerationController < ActionController::API
  include Events::Types

  # Stamps moderation state onto a comment conversation's custom_attributes
  # and (for hide/delete) marks it read, so the list-side ConversationCard
  # can render a "تم إخفاؤه" / "تم حذفه" pill the same way it already
  # renders the customer-side "تم مسحه" pill.
  #
  # Called by the panel's action endpoint after a successful FB hide /
  # unhide / delete. Auth: shared MARKETING_RESOLVE_SECRET via Bearer.
  #
  # Body:
  #   conversation_id  — Chatwoot conv id to update
  #   comment_id       — FB comment id (just for logging / traceability)
  #   kind             — 'hide' | 'unhide' | 'delete'
  #                      (named `kind` and not `action` because Rails routing
  #                      reserves params[:action] for the controller method
  #                      name — sending `action` here got silently shadowed
  #                      and every call returned 400 invalid_action)
  #   actor_name       — display name of the Chatwoot agent who acted
  #   reason_text      — agent's reason (presets or free text). NULL on unhide.
  def update_state
    secret = request.headers['Authorization'].to_s.sub(/^Bearer /, '')
    expected = ENV['MARKETING_RESOLVE_SECRET'].to_s
    return render(json: { ok: false, error: 'unauthorized' }, status: :unauthorized) if expected.empty? || secret != expected

    conv_id = params[:conversation_id].to_i
    action_kind = params[:kind].to_s
    return render(json: { ok: false, error: 'missing_params' }, status: :bad_request) if conv_id.zero?
    return render(json: { ok: false, error: 'invalid_kind' }, status: :bad_request) unless %w[hide unhide delete].include?(action_kind)

    conv = Conversation.find_by(id: conv_id)
    return render(json: { ok: true, found: false }) if conv.nil?

    attrs = (conv.custom_attributes || {}).deep_dup
    now_iso = Time.current.iso8601
    actor_name = params[:actor_name].to_s.presence
    reason_text = params[:reason_text].to_s.presence

    case action_kind
    when 'hide'
      attrs['comment_hidden_at'] = now_iso
      attrs['comment_hidden_by'] = actor_name
      attrs['comment_hidden_reason'] = reason_text
      attrs.delete('comment_deleted_at')
    when 'unhide'
      attrs.delete('comment_hidden_at')
      attrs.delete('comment_hidden_by')
      attrs.delete('comment_hidden_reason')
    when 'delete'
      attrs['comment_deleted_at'] = now_iso
      attrs['comment_deleted_by'] = actor_name
      attrs['comment_deleted_reason'] = reason_text
      attrs.delete('comment_hidden_at')
      attrs.delete('comment_hidden_by')
      attrs.delete('comment_hidden_reason')
    end

    conv.update!(custom_attributes: attrs)

    # hide/delete also marks the conversation read — the customer-facing
    # comment is no longer effective, so there's nothing for the agent to
    # follow up on. unhide leaves read state alone (the conversation is
    # back in play).
    mark_read!(conv) if action_kind != 'unhide'

    render json: { ok: true, found: true, conversation_id: conv.id, action: action_kind }
  end

  private

  def mark_read!(conv)
    now = Time.current
    conv.update_columns(agent_last_seen_at: now, assignee_last_seen_at: now) # rubocop:disable Rails/SkipsModelValidations
    Rails.configuration.dispatcher.dispatch(CONVERSATION_READ, now, conversation: conv)
  end
end
