module AvailabilityStatusable
  extend ActiveSupport::Concern

  def online_presence?
    obj_id = is_a?(Contact) ? id : user_id
    ::OnlineStatusTracker.get_presence(account_id, self.class.name, obj_id)
  end

  def availability_status
    if is_a? Contact
      contact_availability_status
    else
      user_availability_status
    end
  end

  private

  def contact_availability_status
    # Eltafouk: list endpoints prime `Thread.current[:conv_preload_availability]`
    # with a Set of online contact IDs from a single ZRANGEBYSCORE, so we
    # short-circuit the per-row ZSCORE here. Falls through to the original
    # presence check when no preload is active (single-record endpoints,
    # websocket pushes, etc.).
    preload = Thread.current[:conv_preload_availability]
    if preload && preload[:contact_ids]
      return preload[:contact_ids].include?(id.to_s) ? 'online' : 'offline'
    end

    online_presence? ? 'online' : 'offline'
  end

  def user_availability_status
    # we are not considering presence in this case. Just returns the availability
    return availability unless auto_offline

    # Eltafouk: list endpoints prime `Thread.current[:conv_preload_availability]`
    # with a hash of {user_id => status} from a single HMGET. Use it when
    # present; fall back to per-row ZSCORE+GET otherwise.
    preload = Thread.current[:conv_preload_availability]
    if preload && preload[:users]
      cached = preload[:users][user_id.to_s]
      # nil key => user is offline (not in the active set); empty value =>
      # active but no explicit status, fall back to DB `availability`.
      return 'offline' unless cached

      return cached.presence || availability
    end

    # availability as a fallback in case the status is not present in redis
    online_presence? ? (::OnlineStatusTracker.get_status(account_id, user_id) || availability) : 'offline'
  end
end
