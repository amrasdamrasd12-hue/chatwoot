# ref: https://github.com/jgorset/facebook-messenger#make-a-configuration-provider
class ChatwootFbProvider < Facebook::Messenger::Configuration::Providers::Base
  def valid_verify_token?(_verify_token)
    GlobalConfigService.load('FB_VERIFY_TOKEN', '')
  end

  def app_secret_for(_page_id)
    GlobalConfigService.load('FB_APP_SECRET', '')
  end

  def access_token_for(page_id)
    Channel::FacebookPage.where(page_id: page_id).last.page_access_token
  end

  private

  def bot
    Chatwoot::Bot
  end
end

Rails.application.reloader.to_prepare do
  Facebook::Messenger.configure do |config|
    config.provider = ChatwootFbProvider.new
  end

  Facebook::Messenger::Bot.on :message do |message|
    Webhooks::FacebookEventsJob.perform_later(message.to_json)
  end

  Facebook::Messenger::Bot.on :delivery do |delivery|
    Rails.logger.info "Recieved delivery status #{delivery.to_json}"
    Webhooks::FacebookDeliveryJob.perform_later(delivery.to_json)
  end

  Facebook::Messenger::Bot.on :read do |read|
    Rails.logger.info "Recieved read status  #{read.to_json}"
    Webhooks::FacebookDeliveryJob.perform_later(read.to_json)
  end

  Facebook::Messenger::Bot.on :message_echo do |message|
    # Add delay to prevent race condition where echo arrives before send message API completes
    # This avoids duplicate messages when echo comes early during API processing
    Webhooks::FacebookEventsJob.set(wait: 2.seconds).perform_later(message.to_json)
  end

  # Register message_edit event — the gem has no built-in support for it.
  # We need three steps: (1) define a parser class, (2) add it to Incoming::EVENTS
  # (a frozen Hash used by parse()), and (3) add the symbol to Bot::EVENTS
  # (a frozen Array checked by Bot.on).
  unless Facebook::Messenger::Incoming.const_defined?(:MessageEdit)
    Facebook::Messenger::Incoming.const_set(
      :MessageEdit,
      Class.new { include Facebook::Messenger::Incoming::Common }
    )
  end

  unless Facebook::Messenger::Incoming::EVENTS.key?('message_edit')
    new_incoming = Facebook::Messenger::Incoming::EVENTS.merge(
      'message_edit' => Facebook::Messenger::Incoming::MessageEdit
    )
    Facebook::Messenger::Incoming.send(:remove_const, :EVENTS)
    Facebook::Messenger::Incoming.const_set(:EVENTS, new_incoming)
  end

  unless Facebook::Messenger::Bot::EVENTS.include?(:message_edit)
    new_bot_events = Facebook::Messenger::Bot::EVENTS.to_a + [:message_edit]
    Facebook::Messenger::Bot.send(:remove_const, :EVENTS)
    Facebook::Messenger::Bot.const_set(:EVENTS, new_bot_events)
  end

  Facebook::Messenger::Bot.on :reaction do |reaction|
    reaction_json = JSON.parse(reaction.to_json)
    messaging = reaction_json['messaging'] || reaction_json
    reaction_data = messaging['reaction'] || reaction_json['reaction']
    next unless reaction_data

    mid = reaction_data['mid']
    action = reaction_data['action']
    emoji = reaction_data['emoji']
    emoji += "\uFE0F" if emoji == "\u2764" # Normalize black heart to red heart
    sender_id = (messaging.dig('sender', 'id') || reaction_json.dig('sender', 'id')).to_s

    target_message = Message.find_by(source_id: mid)
    next unless target_message

    reactions = target_message.content_attributes['reactions'] || []
    reactions.reject! { |r| r['sender_source_id'] == sender_id }

    if action == 'react' && emoji.present?
      reactions << {
        'emoji' => emoji,
        'sender_source_id' => sender_id,
        'sender_name' => target_message.conversation&.contact&.name,
        'timestamp' => Time.current.to_i
      }
    end

    target_message.content_attributes['reactions'] = reactions
    target_message.save!
    target_message.send_update_event
  end

  Facebook::Messenger::Bot.on :message_edit do |event|
    edit_data = event.messaging['message_edit']
    next unless edit_data

    target_message = Message.find_by(source_id: edit_data['mid'])
    next unless target_message && edit_data['text'].present?

    target_message.update!(content: edit_data['text'])
    target_message.send_update_event
  end
end
