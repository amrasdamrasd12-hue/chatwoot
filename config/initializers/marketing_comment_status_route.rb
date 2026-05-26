Rails.application.config.after_initialize do
  Rails.application.routes.append do
    post '/_mkt/comments/:comment_id/mark_deleted', to: 'marketing_comment_status#mark_deleted'
  end
  Rails.logger.info('[mkt-patch] installed comment_status route')
end
