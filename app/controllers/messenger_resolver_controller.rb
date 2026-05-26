class MessengerResolverController < ActionController::API
  # PSID → contact lookup used by the panel mirror (eltafouk-platform) to
  # route mirrored DMs to the correct Chatwoot inbox.
  #
  # Auth: shared MARKETING_RESOLVE_SECRET via `Authorization: Bearer …`.
  #
  # Returns three signals so the caller can decide how to POST `/conversations`
  # without falling into Chatwoot's "lookup by source_id only" fallback in
  # Api::V1::Accounts::ConversationsController#contact_inbox, which would
  # otherwise reuse a contact_inbox from a *different* inbox (e.g. the comments
  # inbox) and route the new conversation there:
  #   * `contact_id` — present whenever this PSID has any contact_inbox in the
  #     account (in the target inbox OR any sibling inbox). Caller passes it
  #     to `/conversations` so Chatwoot's ContactInboxBuilder runs and creates
  #     the contact_inbox in the target inbox if missing.
  #   * `open_conversation_id` — the open conversation in the *target* inbox
  #     only. When set the caller reuses it instead of opening a duplicate.
  #   * `cross_inbox` — true when the contact was found only through a sibling
  #     inbox (debugging signal; not load-bearing).
  def resolve
    secret = request.headers['Authorization'].to_s.sub(/^Bearer /, '')
    expected = ENV['MARKETING_RESOLVE_SECRET'].to_s
    return render(json: { ok: false, error: 'unauthorized' }, status: :unauthorized) if expected.empty? || secret != expected

    inbox_id = params[:inbox_id].to_i
    source_id = params[:source_id].to_s
    return render(json: { ok: false, error: 'missing_params' }, status: :bad_request) if inbox_id.zero? || source_id.empty?

    in_target = ContactInbox.find_by(inbox_id: inbox_id, source_id: source_id)
    in_sibling = in_target.nil? ? ContactInbox.where(source_id: source_id).order(:id).first : nil

    return render(json: { ok: true, found: false }) if in_target.nil? && in_sibling.nil?

    contact_id = in_target&.contact_id || in_sibling&.contact_id
    open_conv = Conversation
                .where(contact_id: contact_id, inbox_id: inbox_id, status: 'open')
                .order(created_at: :desc)
                .first

    render json: {
      ok: true,
      found: in_target.present?,
      cross_inbox: in_target.nil?,
      contact_id: contact_id,
      contact_name: Contact.where(id: contact_id).pick(:name),
      open_conversation_id: open_conv&.id
    }
  end
end
