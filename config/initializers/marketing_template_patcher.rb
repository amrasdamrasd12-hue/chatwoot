# Installs an after_create_commit hook on Message that auto-resolves Facebook
# Marketing / Notification templates. Such messages arrive as OUTGOING echoes
# with NULL content and a Meta source_id (m_…) because Facebook echoes the
# template without a text body. The hook enqueues MarketingTemplatePatchJob,
# which fetches the rendered card via the Graph API and patches the message.
#
# Sister of config/initializers/comment_text_patcher.rb. Both MUST stay tracked
# in git — when this file was an untracked server-only customization it was
# silently wiped on a deploy/restart (2026-05-30), leaving template messages
# blank ("لم يتم العثور على محتوى") until restored.
Rails.application.config.to_prepare do
  next unless defined?(Message)

  unless Message.method_defined?(:_mkt_tpl_hook_installed)
    Message.class_eval do
      after_create_commit :_mkt_tpl_enqueue, if: :_mkt_tpl_candidate?

      def _mkt_tpl_hook_installed
        true
      end

      def _mkt_tpl_candidate?
        content.blank? &&
          message_type == 'outgoing' &&
          sender_id.nil? &&
          source_id.to_s.start_with?('m_') &&
          inbox&.channel_type == 'Channel::FacebookPage'
      end

      def _mkt_tpl_enqueue
        MarketingTemplatePatchJob.perform_later(id)
      end
    end
    Rails.logger.info('[mkt-tpl-patch] installed Message after_create_commit hook for marketing templates')
  end
end
