Rails.application.config.after_initialize do
  Rails.application.routes.append do
    get '/_mkt/messenger_resolve', to: 'messenger_resolver#resolve'
  end
  Rails.logger.info('[mkt-patch] installed messenger_resolve route')
end
