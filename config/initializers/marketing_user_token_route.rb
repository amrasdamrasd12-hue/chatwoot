Rails.application.config.after_initialize do
  Rails.application.routes.append do
    get '/_mkt/user_access_token', to: 'marketing_user_token#show'
  end
  Rails.logger.info('[mkt-patch] installed user_access_token route')
end
