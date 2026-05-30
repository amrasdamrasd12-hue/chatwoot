class MarketingCommentStatusController < ActionController::API
  include Events::Types

  # POST /_mkt/comments/:comment_id/mark_deleted[?conversation_id=NN]
  #
  # Stamps `custom_attributes.comment_deleted_at` on the conversation that
  # owns the deleted comment, and marks it read so the list-side card
  # collapses to "تم مسحه" + clears the unread badge.
  #
  # Lookup order:
  #  1. Try matching by `custom_attributes->>'comment_id'` — works for
  #     the common case where the conv was opened on this exact comment.
  #  2. Fall back to the explicit `conversation_id` query param. The panel
  #     passes this whenever it knows it (every /context call does) — it's
  #     needed for the multi-comment case where a contact left several
  #     comments on the same post: Chatwoot groups all those comments
  #     under one conversation, but its `comment_id` attribute is frozen
  #     to the FIRST comment, so newer-comment deletions miss the index
  #     lookup and would otherwise silently return found:false.
  def mark_deleted
    secret = request.headers['Authorization'].to_s.sub(/^Bearer /, '')
    expected = ENV['MARKETING_RESOLVE_SECRET'].to_s
    return render(json: { ok: false, error: 'unauthorized' }, status: :unauthorized) if expected.empty? || secret != expected

    comment_id = params[:comment_id].to_s
    return render(json: { ok: false, error: 'missing_params' }, status: :bad_request) if comment_id.empty?

    conv = resolve_conversation(comment_id, params[:conversation_id])
    return render(json: { ok: true, found: false }) if conv.nil?

    already = conv.custom_attributes['comment_deleted_at'].present?
    unless already
      conv.custom_attributes['comment_deleted_at'] = Time.current.iso8601
      conv.save!
    end

    mark_conversation_read!(conv)

    render json: { ok: true, found: true, conversation_id: conv.id, already_marked: already }
  end

  private

  def resolve_conversation(comment_id, fallback_conv_id)
    conv = Conversation.where("custom_attributes->>'comment_id' = ?", comment_id).order(updated_at: :desc).first
    return conv if conv

    conv_id = fallback_conv_id.to_i
    return nil if conv_id.zero?

    Conversation.find_by(id: conv_id)
  end

  # Mirrors the canonical update_last_seen path in Api::V1::Accounts::ConversationsController:
  # stamp both seen-at columns + broadcast CONVERSATION_READ so connected agents' UIs refresh.
  def mark_conversation_read!(conv)
    now = Time.current
    conv.update_columns(agent_last_seen_at: now, assignee_last_seen_at: now) # rubocop:disable Rails/SkipsModelValidations
    Rails.configuration.dispatcher.dispatch(CONVERSATION_READ, now, conversation: conv)
  end
end
