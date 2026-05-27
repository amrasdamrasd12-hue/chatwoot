Rails.application.config.after_initialize do
  Rails.application.routes.append do
    post '/_mkt/comments/moderation', to: 'marketing_comment_moderation#update_state'
  end
  Rails.logger.info('[mkt-patch] installed comment_moderation route')
end
