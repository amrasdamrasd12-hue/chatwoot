require 'net/http'
require 'uri'
require 'json'

# Sister job to CommentTextPatchJob: when an OUTGOING echo lands in a Facebook
# Page inbox with NULL content and a Meta source_id (m_…), it is almost always
# a Marketing / Notification template (e.g. "العروض والإعلامات") that Facebook
# echoes WITHOUT a text body — only an attachment of type `template`, which
# Chatwoot drops. Fetch the rendered card from the dashboard
# /api/marketing/resolve endpoint (which reads the template via the Graph API)
# and patch the message `content` + `content_attributes.meta_template`.
#
# Enqueued by the after_create_commit hook installed in
# config/initializers/marketing_template_patcher.rb.
class MarketingTemplatePatchJob < ApplicationJob
  queue_as :low

  RESOLVE_URL = 'https://api.eltafouk.com/app/api/marketing/resolve'.freeze
  RETRY_DELAYS = [3, 15, 60].freeze

  def perform(message_id, attempt = 0)
    msg = patchable_message(message_id)
    return if msg.nil?

    res = resolve(msg)
    return handle_failure(message_id, res, attempt) unless res && res['ok']

    apply_patch(msg, res)
  rescue StandardError => e
    Rails.logger.error("[mkt-tpl] msg=#{message_id} error: #{e.class}: #{e.message}")
  end

  private

  def patchable_message(message_id)
    msg = Message.find_by(id: message_id)
    return if msg.nil? || msg.content.present? || !candidate?(msg)

    msg
  end

  def candidate?(msg)
    msg.message_type == 'outgoing' &&
      msg.sender_id.nil? &&
      msg.source_id.to_s.start_with?('m_') &&
      msg.inbox&.channel_type == 'Channel::FacebookPage'
  end

  def resolve(msg)
    secret = ENV['MARKETING_RESOLVE_SECRET'].to_s
    if secret.empty?
      Rails.logger.warn('[mkt-tpl] no MARKETING_RESOLVE_SECRET')
      return
    end

    page_id = msg.inbox.channel.try(:page_id).to_s
    return if page_id.empty?

    post_json(RESOLVE_URL, { source_id: msg.source_id, page_id: page_id }, secret)
  end

  def apply_patch(msg, res)
    content = res['content'].to_s.strip
    return if content.empty?

    attrs = (msg.content_attributes || {}).merge('meta_template' => res['meta_template'])
    msg.update!(content: content, content_attributes: attrs)
    Rails.logger.info("[mkt-tpl] msg=#{msg.id} patched (len=#{content.length})")
  end

  def handle_failure(message_id, res, attempt)
    err = res && res['error']
    if attempt < RETRY_DELAYS.length && transient?(err)
      self.class.set(wait: RETRY_DELAYS[attempt].seconds).perform_later(message_id, attempt + 1)
    else
      Rails.logger.info("[mkt-tpl] msg=#{message_id} skipped: #{err.inspect}")
    end
  end

  def transient?(err)
    s = err.to_s
    s.include?('does not exist') || s.include?('timed out') || s.include?('graph_5') || s.include?('no_messaging_token')
  end

  def post_json(url, body, secret)
    uri = URI(url)
    req = Net::HTTP::Post.new(uri)
    req['Authorization'] = "Bearer #{secret}"
    req['Content-Type']  = 'application/json'
    req.body = body.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.read_timeout = 15
    http.open_timeout = 5
    res = http.request(req)
    begin
      JSON.parse(res.body)
    rescue StandardError
      nil
    end
  end
end
