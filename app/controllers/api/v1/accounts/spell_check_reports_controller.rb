# Eltafouk: aggregated spell-check audit data for the per-agent
# reports page. Returns:
#   - `summary`      : grand totals + global category breakdown
#   - `by_agent`     : per-user breakdown (behaviour + error categories +
#                      that agent's most repeated mistakes)
#   - `by_day`       : per-day decision timeseries
#   - `top_mistakes` : the most repeated wrong→right corrections overall
#   - `meta.segments`: counts by strictness / model / surface so the UI
#                      can warn that comparing agents on different rulers
#                      isn't apples-to-apples
# All filtered by an optional `since`/`until` window and optional
# `user_ids[]` selection.
class Api::V1::Accounts::SpellCheckReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  DECISIONS = SpellCheckEvent::DECISIONS - ['unknown']
  TOP_MISTAKES_LIMIT = 15
  AGENT_MISTAKES_LIMIT = 5

  def index
    range_from, range_to = parsed_range
    events = scoped(Current.account.spell_check_events, range_from, range_to)
    fixes = scoped(Current.account.spell_check_fixes, range_from, range_to)

    render json: {
      meta: {
        from: range_from.iso8601,
        to: range_to.iso8601,
        decisions: DECISIONS,
        categories: SpellCheckFix::CATEGORIES,
        segments: segments_for(events)
      },
      summary: summary_for(events).merge(fixes_summary(fixes)),
      by_agent: agent_breakdown(events, fixes),
      by_day: daily_series(events, range_from, range_to),
      top_mistakes: top_mistakes(fixes)
    }
  end

  private

  def scoped(relation, from, to)
    relation = relation.where(created_at: from..to)
    relation = relation.where(user_id: params[:user_ids]) if params[:user_ids].present?
    relation
  end

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

  # Global category breakdown over every captured fix in range.
  def fixes_summary(scope)
    by_cat = scope.unscope(:order).group(:category).count
    {
      total_fixes: by_cat.values.sum,
      by_category: SpellCheckFix::CATEGORIES.index_with { |c| by_cat[c] || 0 }
    }
  end

  # The most repeated wrong→right corrections across everyone — the
  # "house-wide" weak spots worth a team-wide note.
  def top_mistakes(scope, limit = TOP_MISTAKES_LIMIT)
    scope.unscope(:order)
         .group(:wrong, :right, :category)
         .count
         .map { |(wrong, right, category), count| { wrong: wrong, right: right, category: category, count: count } }
         .sort_by { |m| -m[:count] }
         .first(limit)
  end

  def agent_breakdown(scope, fixes)
    agents = decision_rows(scope)
    attach_error_sums(agents, scope)
    attach_fix_data(agents, fixes)
    agents.values.sort_by { |a| -a[:total] }
  end

  def decision_rows(scope)
    rows = scope.unscope(:order)
                .joins('LEFT JOIN users ON users.id = spell_check_events.user_id')
                .group('users.id', 'users.name', 'users.email', :decision)
                .count
    agents = {}
    rows.each do |(user_id, name, email, decision), count|
      key = user_id || 0
      agents[key] ||= blank_agent(user_id, name, email)
      next unless DECISIONS.include?(decision)

      agents[key][:decisions][decision] = count
      agents[key][:total] += count
    end
    agents
  end

  def blank_agent(user_id, name, email)
    {
      user_id: user_id,
      name: name || 'بدون موظف',
      email: email,
      decisions: DECISIONS.index_with { 0 },
      total: 0,
      errors_caught: 0,
      categories: SpellCheckFix::CATEGORIES.index_with { 0 },
      top_mistakes: []
    }
  end

  def attach_error_sums(agents, scope)
    sums = scope.unscope(:order).where.not(user_id: nil).group(:user_id).sum(:errors_count)
    agents.each_value do |row|
      row[:errors_caught] = sums[row[:user_id]] || 0 if row[:user_id]
    end
  end

  # Per-agent error categories + that agent's most repeated mistakes.
  def attach_fix_data(agents, fixes)
    attach_categories(agents, fixes)
    attach_top_mistakes(agents, fixes)
  end

  def attach_categories(agents, fixes)
    fixes.unscope(:order).group(:user_id, :category).count.each do |(uid, category), count|
      agent = agents[uid || 0]
      next unless agent && SpellCheckFix::CATEGORIES.include?(category)

      agent[:categories][category] = count
    end
  end

  def attach_top_mistakes(agents, fixes)
    per_agent = Hash.new { |h, k| h[k] = [] }
    fixes.unscope(:order).group(:user_id, :wrong, :right, :category).count.each do |(uid, wrong, right, category), count|
      per_agent[uid || 0] << { wrong: wrong, right: right, category: category, count: count }
    end
    per_agent.each do |key, list|
      next unless agents[key]

      agents[key][:top_mistakes] = list.sort_by { |m| -m[:count] }.first(AGENT_MISTAKES_LIMIT)
    end
  end

  # Fairness context: which strictness levels / models / surfaces the
  # filtered data spans. Comparing agents measured on different rulers is
  # misleading, so the UI surfaces this.
  def segments_for(scope)
    base = scope.unscope(:order)
    {
      by_strictness: base.group(:strictness).count.transform_keys(&:to_s),
      by_model: base.group(:model_used).count.transform_keys { |k| k || 'unknown' },
      by_surface: base.group(:surface).count.transform_keys { |k| k || 'unknown' }
    }
  end

  def daily_series(scope, from, to)
    counts = scope.unscope(:order)
                  .group_by_day(:created_at, range: from..to, default_value: 0)
                  .group(:decision)
                  .count
    days = counts.each_with_object({}) do |((day, decision), count), acc|
      key = day.to_date.iso8601
      acc[key] ||= DECISIONS.index_with { 0 }.merge(date: key)
      acc[key][decision] = count if DECISIONS.include?(decision)
    end
    days.values.sort_by { |d| d[:date] }
  end

  def check_authorization
    authorize(Account, :show?)
  end
end
