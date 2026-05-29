# Eltafouk: aggregated spell-check audit data for the per-agent
# reports page. Returns three slices:
#   - `summary`   : grand totals over the filtered range
#   - `by_agent`  : per-user breakdown for the comparison table/chart
#   - `by_day`    : per-day timeseries (defaults shrink to the range)
# All filtered by an optional `since`/`until` window and optional
# `user_ids[]` selection so the UI can power both "all agents over the
# month" and "agent X today" views with one endpoint.
class Api::V1::Accounts::SpellCheckReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  DECISIONS = SpellCheckEvent::DECISIONS - ['unknown']

  def index
    range_from, range_to = parsed_range
    base = Current.account.spell_check_events
                  .where(created_at: range_from..range_to)
    base = base.where(user_id: params[:user_ids]) if params[:user_ids].present?

    render json: {
      meta: { from: range_from.iso8601, to: range_to.iso8601, decisions: DECISIONS },
      summary: summary_for(base),
      by_agent: agent_breakdown(base),
      by_day: daily_series(base, range_from, range_to)
    }
  end

  private

  # Range parsing — default to last 30 days when no params given.
  def parsed_range
    to_param = params[:until].presence
    from_param = params[:since].presence
    to = to_param ? Time.zone.parse(to_param) : Time.current
    from = from_param ? Time.zone.parse(from_param) : (to - 30.days)
    [from.beginning_of_day, to.end_of_day]
  end

  def summary_for(scope)
    counts = scope.group(:decision).count.transform_keys(&:to_s)
    total = counts.values.sum
    {
      total_checks: total,
      decisions: DECISIONS.index_with { |d| counts[d] || 0 },
      has_errors_count: scope.where(has_errors: true).count,
      no_errors_count: scope.where(has_errors: false).count,
      total_errors_caught: scope.sum(:errors_count)
    }
  end

  def agent_breakdown(scope)
    rows = scope.unscope(:order)
                .joins('LEFT JOIN users ON users.id = spell_check_events.user_id')
                .group('users.id', 'users.name', 'users.email', :decision)
                .count
    agents = {}
    rows.each do |(user_id, name, email, decision), count|
      key = user_id || 0
      agents[key] ||= {
        user_id: user_id,
        name: name || 'بدون موظف',
        email: email,
        decisions: DECISIONS.index_with { 0 },
        total: 0,
        errors_caught: 0
      }
      next unless DECISIONS.include?(decision)

      agents[key][:decisions][decision] = count
      agents[key][:total] += count
    end
    # Sum errors_count separately — can't tag onto the group above without
    # SELECT clutter.
    error_sums = scope.unscope(:order)
                      .where.not(user_id: nil)
                      .group(:user_id)
                      .sum(:errors_count)
    agents.each_value do |row|
      next unless row[:user_id]

      row[:errors_caught] = error_sums[row[:user_id]] || 0
    end
    agents.values.sort_by { |a| -a[:total] }
  end

  def daily_series(scope, from, to)
    scope.unscope(:order)
         .group_by_day(:created_at, range: from..to, default_value: 0)
         .group(:decision)
         .count
         .each_with_object({}) do |((day, decision), count), acc|
      key = day.to_date.iso8601
      acc[key] ||= DECISIONS.index_with { 0 }.merge(date: key)
      acc[key][decision] = count if DECISIONS.include?(decision)
    end.values.sort_by { |d| d[:date] }
  end

  def check_authorization
    authorize(Account, :show?)
  end
end
