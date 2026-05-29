class MarketingUserTokenController < ActionController::API
  # GET /_mkt/user_access_token?user_id=10
  #
  # Returns the primary Devise AccessToken for a given Chatwoot User so the
  # eltafouk-platform (Next.js panel) can act on Chatwoot APIs *as* the
  # currently-active agent instead of the shared admin token. This is what
  # lets a mirrored DM (from a comment private_reply) land in Chatwoot with
  # the right sender_id — so per-agent reports actually attribute the DM
  # to Zahra/Noha/etc. rather than to Amr (whose CHATWOOT_TOKEN the panel
  # was previously falling back to for every mirror call).
  #
  # Auth: shared MARKETING_RESOLVE_SECRET via `Authorization: Bearer …`,
  # matching the other /_mkt/* endpoints (messenger_resolver,
  # marketing_comment_status, marketing_message_attribution). No public
  # exposure.
  def show
    secret = request.headers['Authorization'].to_s.sub(/^Bearer /, '')
    expected = ENV['MARKETING_RESOLVE_SECRET'].to_s
    return render(json: { ok: false, error: 'unauthorized' }, status: :unauthorized) if expected.empty? || secret != expected

    user_id = params[:user_id].to_i
    return render(json: { ok: false, error: 'missing_user_id' }, status: :bad_request) if user_id.zero?

    user = User.find_by(id: user_id)
    return render(json: { ok: false, error: 'user_not_found' }, status: :not_found) if user.nil?

    at = AccessToken.find_by(owner_type: 'User', owner_id: user_id)
    return render(json: { ok: false, error: 'no_access_token' }, status: :not_found) if at.nil? || at.token.to_s.empty?

    render json: {
      ok: true,
      user_id: user.id,
      user_name: user.name,
      token: at.token
    }
  end
end
