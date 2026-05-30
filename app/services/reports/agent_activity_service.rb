# Eltafouk: powers the "تقرير نشاط الموظفين" reports page. Aggregates, per
# agent and over a date range (Africa/Cairo), how much each one replied
# (DM + comments), across which channels, during which shift, and how fast
# they responded.
#
# Why a bespoke service instead of Chatwoot's native agent reports:
#   * Comment replies are created by the FB relay user (page-relay); the
#     real author lives in message.content_attributes['eltafouk_agent_id'].
#     content_attributes is a serialized-JSON *text* column, so Postgres
#     `->>` can't reach it — we parse it in Ruby. Native reports miss this.
#   * Response time is measured INSIDE each agent's detected shift
#     (first→last activity that day), because shifts are variable and the
#     account has no fixed business-hours config. Each reporting_event
#     window is clipped to the agent's shift before averaging.
class Reports::AgentActivityService # rubocop:disable Metrics/ClassLength
  TZ = 'Cairo'.freeze
  # Comment→agent attribution only began populating on this date; older
  # comment replies carry no author. Surfaced in meta so the UI can warn
  # when the selected range reaches further back.
  COMMENT_ATTRIBUTION_SINCE = Date.new(2026, 5, 27)
  # Only the FB relay is a true non-human account; the admin (Amr Ashraf)
  # replies for real, so he's counted as a regular agent.
  SYSTEM_EMAILS = %w[page-relay@eltafouk.local].freeze

  CHANNEL_LABELS = {
    'Channel::FacebookPage' => 'facebook',
    'Channel::Instagram' => 'instagram',
    'Channel::Whatsapp' => 'whatsapp',
    'Channel::Api' => 'comments'
  }.freeze
  CHANNEL_KEYS = %w[facebook instagram whatsapp comments other].freeze

  def initialize(account:, from:, to:, user_ids: nil, inbox_ids: nil)
    @account = account
    @from = from
    @to = to
    @user_filter = Array(user_ids).map(&:to_i).reject(&:zero?).to_set.presence
    @inbox_filter = Array(inbox_ids).map(&:to_i).reject(&:zero?).to_set.presence
    @agents = {}
    @unattributed_comments = 0
    @day_totals = Hash.new { |h, k| h[k] = { dm: 0, comment: 0 } }
    @hour_totals = Array.new(24, 0)
    @channel_totals = Hash.new(0)
  end

  def call
    load_inboxes
    load_dm_and_notes
    load_comments
    load_response_times
    {
      meta: meta,
      summary: summary,
      by_agent: agents_payload,
      by_day: day_series,
      by_hour: @hour_totals,
      by_channel: CHANNEL_KEYS.index_with { |k| @channel_totals[k] }
    }
  end

  private

  def zone
    @zone ||= ActiveSupport::TimeZone[TZ]
  end

  def cairo_date(time)
    time.in_time_zone(zone).to_date
  end

  def load_inboxes
    rows = @account.inboxes.pluck(:id, :channel_type)
    @inbox_channel = rows.to_h.transform_values { |ct| CHANNEL_LABELS[ct] || 'other' }
    @api_inbox_ids = rows.select { |_, ct| ct == 'Channel::Api' }.to_set(&:first)
  end

  # Pass A — agent-authored messages outside the comment inboxes: DM
  # replies (outgoing, public) and private notes. sender_type 'User'
  # guarantees a human author; the comment inboxes are excluded here and
  # handled in pass B where the real author lives in content_attributes.
  def load_dm_and_notes
    scope = @account.messages
                    .where(created_at: @from..@to, sender_type: 'User')
                    .where(message_type: %i[outgoing])
                    .where.not(inbox_id: @api_inbox_ids.to_a)
    scope = scope.where(inbox_id: @inbox_filter.to_a) if @inbox_filter
    cols = %i[sender_id conversation_id inbox_id created_at private]
    scope.pluck(*cols).each { |row| record_dm_or_note(*row) }
  end

  def record_dm_or_note(sender_id, conv_id, inbox_id, created_at, is_private)
    return if @user_filter&.exclude?(sender_id)

    agent = agent_for(sender_id)
    register_activity(agent, created_at)
    return (agent[:notes] += 1) if is_private

    channel = @inbox_channel[inbox_id] || 'other'
    agent[:dm] += 1
    agent[:conversations] << conv_id
    agent[:by_channel][channel] += 1
    @channel_totals[channel] += 1
    agent_day(agent, created_at)[:dm] += 1
    tally_time(created_at, :dm)
  end

  # Pass B — comment replies. Sent by the relay user inside Channel::Api
  # inboxes; the human author is content_attributes['eltafouk_agent_id'].
  # content_attributes is serialized JSON in a text column, so we read it
  # through the AR accessor rather than SQL.
  def load_comments
    return if @inbox_filter && !@inbox_filter.intersect?(@api_inbox_ids)

    scope = @account.messages
                    .where(created_at: @from..@to, message_type: :outgoing, private: false)
                    .where(inbox_id: @api_inbox_ids.to_a)
    scope.select(:id, :conversation_id, :created_at, :content_attributes).find_each { |msg| record_comment(msg) }
  end

  def record_comment(msg)
    agent_id = msg.content_attributes&.dig('eltafouk_agent_id').to_s.strip
    return (@unattributed_comments += 1) if agent_id.empty?

    sender_id = agent_id.to_i
    return if @user_filter&.exclude?(sender_id)

    agent = agent_for(sender_id)
    register_activity(agent, msg.created_at)
    agent[:comment] += 1
    agent[:conversations] << msg.conversation_id
    agent[:by_channel]['comments'] += 1
    @channel_totals['comments'] += 1
    agent_day(agent, msg.created_at)[:comment] += 1
    tally_time(msg.created_at, :comment)
  end

  # Pass C — response speed, clipped to each agent's detected shift.
  # first_response = time to first reply on a conversation; reply_time =
  # every customer→agent turn. Both store event_start_time (customer
  # message) and event_end_time (agent reply). The in-shift portion is
  # event_end − max(event_start, shift_start) so an agent isn't charged
  # for messages that arrived before their shift began.
  def load_response_times
    scope = @account.reporting_events
                    .where(name: %w[first_response reply_time], created_at: @from..@to)
                    .where.not(user_id: nil)
                    .where.not(event_start_time: nil)
                    .where.not(event_end_time: nil)
    scope.pluck(:name, :user_id, :event_start_time, :event_end_time).each do |name, user_id, start_t, end_t|
      next if @user_filter&.exclude?(user_id)
      next unless @agents.key?(user_id)

      secs = in_shift_seconds(@agents[user_id], start_t, end_t)
      next if secs.nil?

      bucket = name == 'first_response' ? :first_response_secs : :reply_secs
      @agents[user_id][bucket] << secs
    end
  end

  def in_shift_seconds(agent, start_t, end_t)
    shift = agent[:shifts][cairo_date(end_t)]
    return nil unless shift

    shift_start, shift_end = shift
    effective_start = [start_t, shift_start].max
    effective_end = [end_t, shift_end].min
    delta = effective_end - effective_start
    delta.negative? ? 0 : delta.round
  end

  def agent_for(user_id)
    @agents[user_id] ||= begin
      user = User.find_by(id: user_id)
      {
        user_id: user_id,
        name: user&.name || "#?#{user_id}",
        email: user&.email,
        system: SYSTEM_EMAILS.include?(user&.email),
        dm: 0,
        comment: 0,
        notes: 0,
        conversations: Set.new,
        by_channel: Hash.new(0),
        shifts: {},
        daily: {},
        first_response_secs: [],
        reply_secs: []
      }
    end
  end

  # Per-Cairo-day reply counts for an agent — feeds the per-day shift
  # breakdown so multi-day ranges show one window per day instead of a
  # nonsensical earliest-start→latest-end envelope.
  def agent_day(agent, time)
    agent[:daily][cairo_date(time)] ||= { dm: 0, comment: 0 }
  end

  # Track first/last activity per Cairo day so we can both report the
  # shift window and clip response times to it.
  def register_activity(agent, time)
    d = cairo_date(time)
    span = agent[:shifts][d]
    if span
      span[0] = time if time < span[0]
      span[1] = time if time > span[1]
    else
      agent[:shifts][d] = [time, time]
    end
  end

  def tally_time(time, kind)
    local = time.in_time_zone(zone)
    @day_totals[local.to_date][kind] += 1
    @hour_totals[local.hour] += 1
  end

  def avg(list)
    return nil if list.empty?

    (list.sum.to_f / list.size).round
  end

  def agents_payload
    @agents.values.map { |a| serialize_agent(a) }.sort_by { |a| -a[:total] }
  end

  def serialize_agent(agent)
    days = agent[:shifts].keys.sort
    {
      user_id: agent[:user_id],
      name: agent[:name],
      email: agent[:email],
      system: agent[:system],
      dm: agent[:dm],
      comment: agent[:comment],
      notes: agent[:notes],
      total: agent[:dm] + agent[:comment],
      conversations: agent[:conversations].size,
      by_channel: CHANNEL_KEYS.index_with { |k| agent[:by_channel][k] },
      active_days: days.size,
      daily: days.map { |d| daily_breakdown(agent, d) },
      avg_first_response_secs: avg(agent[:first_response_secs]),
      avg_reply_secs: avg(agent[:reply_secs])
    }
  end

  def daily_breakdown(agent, day)
    start_t, end_t = agent[:shifts][day]
    counts = agent[:daily][day] || { dm: 0, comment: 0 }
    {
      date: day.iso8601,
      shift_start: start_t.in_time_zone(zone).strftime('%H:%M'),
      shift_end: end_t.in_time_zone(zone).strftime('%H:%M'),
      dm: counts[:dm],
      comment: counts[:comment],
      total: counts[:dm] + counts[:comment]
    }
  end

  def day_series
    @day_totals.keys.sort.map do |d|
      t = @day_totals[d]
      { date: d.iso8601, dm: t[:dm], comment: t[:comment], total: t[:dm] + t[:comment] }
    end
  end

  def summary
    payload = @agents.values
    dm = payload.sum { |a| a[:dm] }
    comment = payload.sum { |a| a[:comment] }
    {
      total_replies: dm + comment,
      dm_replies: dm,
      comment_replies: comment,
      unattributed_comments: @unattributed_comments,
      notes: payload.sum { |a| a[:notes] },
      total_conversations: payload.sum { |a| a[:conversations].size },
      active_agents: payload.count { |a| !a[:system] && (a[:dm] + a[:comment]).positive? },
      busiest_hour: busiest_hour_payload,
      busiest_day: busiest_day_payload
    }
  end

  def busiest_hour_payload
    count, hour = @hour_totals.each_with_index.max_by { |c, _| c }
    count&.positive? ? { hour: hour, count: count } : nil
  end

  def busiest_day_payload
    day = day_series.max_by { |d| d[:total] }
    day && day[:total].positive? ? day : nil
  end

  def meta
    {
      from: @from.in_time_zone(zone).iso8601,
      to: @to.in_time_zone(zone).iso8601,
      timezone: 'Africa/Cairo',
      comment_attribution_since: COMMENT_ATTRIBUTION_SINCE.iso8601,
      comment_attribution_partial: cairo_date(@from) < COMMENT_ATTRIBUTION_SINCE
    }
  end
end
