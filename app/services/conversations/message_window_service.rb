class Conversations::MessageWindowService
  MESSAGING_WINDOW_24_HOURS = 24.hours
  MESSAGING_WINDOW_7_DAYS = 7.days

  def initialize(conversation, last_incoming_message: nil)
    @conversation = conversation
    # Eltafouk: list endpoints preload the latest incoming message in a
    # single bulk query and hand it in so we skip the per-row lookup.
    # When unset (single-record callers), `last_incoming_message` does
    # its own scoped query as before.
    @last_incoming_message = last_incoming_message
  end

  def can_reply?
    return true if messaging_window.blank?

    last_message_in_messaging_window?(messaging_window)
  end

  private

  def messaging_window
    case @conversation.inbox.channel_type
    when 'Channel::Api'
      api_messaging_window
    when 'Channel::FacebookPage'
      messenger_messaging_window
    when 'Channel::Instagram'
      instagram_messaging_window
    when 'Channel::Tiktok'
      tiktok_messaging_window
    when 'Channel::Whatsapp'
      MESSAGING_WINDOW_24_HOURS
    when 'Channel::TwilioSms'
      twilio_messaging_window
    end
  end

  def last_message_in_messaging_window?(time)
    return false if last_incoming_message.nil?

    Time.current < last_incoming_message.created_at + time
  end

  def api_messaging_window
    return if @conversation.inbox.channel.additional_attributes['agent_reply_time_window'].blank?

    @conversation.inbox.channel.additional_attributes['agent_reply_time_window'].to_i.hours
  end

  # Check medium of the inbox to determine the messaging window
  def twilio_messaging_window
    @conversation.inbox.channel.medium == 'whatsapp' ? MESSAGING_WINDOW_24_HOURS : nil
  end

  def messenger_messaging_window
    meta_messaging_window('ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT')
  end

  def instagram_messaging_window
    meta_messaging_window('ENABLE_INSTAGRAM_CHANNEL_HUMAN_AGENT')
  end

  def tiktok_messaging_window
    48.hours
  end

  def meta_messaging_window(config_key)
    GlobalConfigService.load(config_key, nil) ? MESSAGING_WINDOW_7_DAYS : MESSAGING_WINDOW_24_HOURS
  end

  def last_incoming_message
    @last_incoming_message ||= @conversation.messages.where(account_id: @conversation.account_id).incoming&.last
  end
end
