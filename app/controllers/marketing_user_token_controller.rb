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
  # matching the other /_mkt/* endpoints. No public exposure.
  #
  # Defense-in-depth: even if the shared secret leaks, this endpoint
  # REFUSES to hand out tokens for SuperAdmin / administrator accounts —
  # so the worst-case escalation from a compromised secret is "act as a
  # regular agent", not "act as the platform admin". Regular agents can
  # already be impersonated to send DMs, which is the whole point of the
  # mirror flow; SuperAdmins can also delete accounts and rotate API
  # keys, which is the line we keep on this side of the firewall.
  PROTECTED_ROLES = %w[administrator super_admin SuperAdmin].freeze
  PROTECTED_EMAILS = ['admin@eltafouk.com'].freeze

  def show
    return render(json: { ok: false, error: 'unauthorized' }, status: :unauthorized) unless authorized?

    user_id = params[:user_id].to_i
    return render(json: { ok: false, error: 'missing_user_id' }, status: :bad_request) if user_id.zero?

    user = User.find_by(id: user_id)
    return render(json: { ok: false, error: 'user_not_found' }, status: :not_found) if user.nil?

    if protected_user?(user)
      Rails.logger.warn("[mkt-user-token] refused token request for protected user id=#{user.id} email=#{user.email}")
      return render(json: { ok: false, error: 'protected_user' }, status: :forbidden)
    end

    at = AccessToken.find_by(owner_type: 'User', owner_id: user_id)
    return render(json: { ok: false, error: 'no_access_token' }, status: :not_found) if at.nil? || at.token.to_s.empty?

    render json: {
      ok: true,
      user_id: user.id,
      user_name: user.name,
      token: at.token
    }
  end

  private

  def authorized?
    expected = ENV['MARKETING_RESOLVE_SECRET'].to_s
    return false if expected.empty?

    presented = request.headers['Authorization'].to_s.sub(/^Bearer /, '')
    return false if presented.empty?

    # SHA-256 hashing both sides guarantees equal-length operands so
    # `secure_compare` (which requires equal-length inputs) doesn't leak
    # the secret length on mismatched submissions.
    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(presented),
      Digest::SHA256.hexdigest(expected)
    )
  end

  def protected_user?(user)
    return true if PROTECTED_EMAILS.include?(user.email.to_s.downcase)

    role = user.try(:role).to_s
    type = user.try(:type).to_s
    PROTECTED_ROLES.include?(role) || PROTECTED_ROLES.include?(type)
  end
end
