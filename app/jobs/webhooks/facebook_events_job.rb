class Webhooks::FacebookEventsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  def perform(message)
    response = ::Integrations::Facebook::MessageParser.new(message)

    key = format(::Redis::Alfred::FACEBOOK_MESSAGE_MUTEX, sender_id: response.sender_id, recipient_id: response.recipient_id)
    with_lock(key) do
      process_message(response)
    end
  end

  def process_message(response)
    if response.edited?
      update_message(response)
    else
      ::Integrations::Facebook::MessageCreator.new(response).perform
    end
  end

  def update_message(response)
    message = Message.find_by(source_id: response.identifier)
    return unless message && response.content.present?

    message.update!(content: response.content)
    message.send_update_event
  end
end
