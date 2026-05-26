Rails.application.config.after_initialize do
  Rails.application.routes.append do
    post '/_mkt/messages/attribute_outgoing', to: 'marketing_message_attribution#attribute_outgoing'
  end
  Rails.logger.info('[mkt-patch] installed message_attribution route')
end
