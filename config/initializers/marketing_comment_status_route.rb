Rails.application.config.after_initialize do
  Rails.application.routes.append do
    post '/_mkt/comments/:comment_id/mark_deleted', to: 'marketing_comment_status#mark_deleted'
    post '/_mkt/comments/attach_media', to: 'marketing_comment_status#attach_media'
  end
  Rails.logger.info('[mkt-patch] installed comment_status + attach_media routes')
end
