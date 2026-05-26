class MarketingCommentStatusController < ActionController::API
  include Events::Types

  def mark_deleted
    secret = request.headers['Authorization'].to_s.sub(/^Bearer /, '')
    expected = ENV['MARKETING_RESOLVE_SECRET'].to_s
    return render(json: { ok: false, error: 'unauthorized' }, status: :unauthorized) if expected.empty? || secret != expected

    comment_id = params[:comment_id].to_s
    return render(json: { ok: false, error: 'missing_params' }, status: :bad_request) if comment_id.empty?

    conv = Conversation.where("custom_attributes->>'comment_id' = ?", comment_id).order(updated_at: :desc).first
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

  # Mirrors the canonical update_last_seen path in Api::V1::Accounts::ConversationsController:
  # stamp both seen-at columns + broadcast CONVERSATION_READ so connected agents' UIs refresh.
  def mark_conversation_read!(conv)
    now = Time.current
    conv.update_columns(agent_last_seen_at: now, assignee_last_seen_at: now) # rubocop:disable Rails/SkipsModelValidations
    Rails.configuration.dispatcher.dispatch(CONVERSATION_READ, now, conversation: conv)
  end
end
