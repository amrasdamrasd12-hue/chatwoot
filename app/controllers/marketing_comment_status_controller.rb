class MarketingCommentStatusController < ActionController::API
  include Events::Types
  include FileTypeHelper

  # attach_media only ever rehosts Facebook/Instagram comment media, so the
  # download target is restricted to Meta's CDNs. This is the SSRF guard: it
  # stops a leaked relay secret from turning the endpoint into a fetch-any-URL
  # proxy that could reach cloud metadata (169.254.169.254) or internal hosts.
  MEDIA_HOST_ALLOWLIST = %w[fbcdn.net fbsbx.com cdninstagram.com facebook.com].freeze
  MAX_MEDIA_BYTES = 25 * 1024 * 1024 # 25 MB ceiling — comment media is tiny

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

  # POST /_mkt/comments/attach_media
  #
  # Creates a message with a downloaded ActiveStorage attachment (image/media)
  # inside the specified conversation. This rehosts the file locally on our server,
  # so it survives Facebook's CDN link expiration (signatures expire after ~2 days).
  def attach_media
    secret = request.headers['Authorization'].to_s.sub(/^Bearer /, '')
    expected = ENV['MARKETING_RESOLVE_SECRET'].to_s
    return render(json: { ok: false, error: 'unauthorized' }, status: :unauthorized) if expected.empty? || secret != expected

    conv_id = params[:conversation_id]
    content = params[:content]
    image_url = params[:image_url]
    message_type = params[:message_type] || 'incoming'

    return render(json: { ok: false, error: 'missing_params' }, status: :bad_request) if conv_id.blank? || image_url.blank?
    return render(json: { ok: false, error: 'invalid_image_url' }, status: :unprocessable_entity) unless allowed_media_url?(image_url)

    conv = Conversation.find_by(id: conv_id)
    return render(json: { ok: false, error: 'conversation_not_found' }, status: :not_found) if conv.nil?

    # Initialize message without saving it yet
    msg = conv.messages.new(
      account: conv.account,
      inbox: conv.inbox,
      message_type: message_type.to_sym,
      content: content.presence
    )

    begin
      # Download file from Facebook Graph API CDN using Down. max_redirects: 0
      # keeps an allowlisted host from bouncing us to an internal address;
      # max_size caps the transfer so a hostile/huge file can't exhaust disk.
      file = Down.download(image_url, max_redirects: 0, max_size: MAX_MEDIA_BYTES)

      # Determine content-type and filename
      content_type = file.content_type || 'image/png'
      ext = content_type.split('/').last || 'png'
      filename = file.original_filename || "attachment.#{ext}"

      # Build attachment and attach file
      att = msg.attachments.new(
        account_id: conv.account_id,
        file_type: file_type(content_type)
      )
      att.file.attach(io: file, filename: filename, content_type: content_type)

      # Save message (saves attachments in the same transaction and dispatches events)
      msg.save!
    rescue => e
      # Detail stays server-side; the client gets a generic code so connection
      # errors can't leak internal hostnames/ports back to the caller.
      Rails.logger.error("[mkt-media] Failed to download or attach media: #{e.class}: #{e.message}")
      return render(json: { ok: false, error: 'media_download_failed' }, status: :unprocessable_entity)
    ensure
      # Down tempfile cleanup
      if file
        file.close
        file.unlink if file.respond_to?(:unlink)
      end
    end

    render json: { ok: true, message_id: msg.id }
  end

  private

  # SSRF guard: only http(s) URLs on Meta's media CDNs may be fetched.
  def allowed_media_url?(url)
    uri = URI.parse(url)
    return false unless %w[http https].include?(uri.scheme)

    host = uri.host.to_s.downcase
    return false if host.empty?

    MEDIA_HOST_ALLOWLIST.any? { |suffix| host == suffix || host.end_with?(".#{suffix}") }
  rescue URI::Error
    false
  end

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
