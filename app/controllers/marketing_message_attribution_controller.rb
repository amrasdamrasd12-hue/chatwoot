class MarketingMessageAttributionController < ActionController::API
  # Tags an outgoing comment-inbox message with the agent who authored it
  # via the panel, so MessagePreview can render "↩ من <agent>" in the
  # conversation list instead of the generic "↩ من الصفحة".
  #
  # Auth: shared MARKETING_RESOLVE_SECRET via `Authorization: Bearer …`.
  #
  # The panel calls this after a successful `public_comment` action. Because
  # the Chatwoot message itself is created by an n8n webhook (which lands a
  # short moment later), the panel POSTs in a small loop with retry — the
  # endpoint just needs to do the matching once. Match strategy:
  #   * Scope to the conversation_id the caller passed
  #   * Outgoing messages only
  #   * Whose `content` equals the snippet the agent typed (after
  #     stripping the same `📎 البوست: …` suffix n8n appends)
  #   * Created within the last `max_age_seconds` window (defaults to 600 s)
  # When multiple match, picks the most recent — the comment thread is the
  # only path that creates this message, so collisions are vanishingly rare.
  def attribute_outgoing
    secret = request.headers['Authorization'].to_s.sub(/^Bearer /, '')
    expected = ENV['MARKETING_RESOLVE_SECRET'].to_s
    return render(json: { ok: false, error: 'unauthorized' }, status: :unauthorized) if expected.empty? || secret != expected

    conv_id = params[:conversation_id].to_i
    content = params[:content].to_s
    agent_name = params[:agent_name].to_s
    agent_id = params[:agent_id].to_s
    max_age = (params[:max_age_seconds].presence || '600').to_i

    return render(json: { ok: false, error: 'missing_params' }, status: :bad_request) if conv_id.zero? || content.empty? || agent_name.empty?

    msg = match_outgoing_message(conv_id, content, max_age)
    return render(json: { ok: true, found: false }) if msg.nil?

    existing = (msg.content_attributes || {}).deep_dup
    existing['eltafouk_agent_name'] = agent_name
    existing['eltafouk_agent_id'] = agent_id if agent_id.present?
    msg.update!(content_attributes: existing)

    render json: { ok: true, found: true, message_id: msg.id }
  end

  private

  def match_outgoing_message(conv_id, content, max_age)
    # Normalize the candidate text the same way MessagePreview strips it on
    # the client — n8n appends a "📎 البوست: <url>" footer to comments that
    # we never typed.
    needle = content.gsub(/\s*[\u{1F4CE}\u{1F517}]\s*البوست:[\s\S]*$/, '').strip
    return nil if needle.empty?

    Message
      .where(conversation_id: conv_id, message_type: :outgoing)
      .where('created_at > ?', max_age.seconds.ago)
      .order(created_at: :desc)
      .limit(20)
      .find { |m| m.content.to_s.gsub(/\s*[\u{1F4CE}\u{1F517}]\s*البوست:[\s\S]*$/, '').strip == needle }
  end
end
