# Eltafouk: serves the "تقرير نشاط الموظفين" reports page. Thin wrapper —
# all aggregation lives in Reports::AgentActivityService. Accepts an
# optional since/until window (Africa/Cairo, defaults to today) plus
# optional user_ids[]/inbox_ids[] scoping.
class Api::V1::Accounts::AgentActivityReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    from, to = parsed_range
    render json: Reports::AgentActivityService.new(
      account: Current.account,
      from: from,
      to: to,
      user_ids: params[:user_ids],
      inbox_ids: params[:inbox_ids]
    ).call
  end

  private

  def parsed_range
    tz = ActiveSupport::TimeZone['Cairo']
    to = params[:until].present? ? tz.parse(params[:until]) : Time.current.in_time_zone(tz)
    from = params[:since].present? ? tz.parse(params[:since]) : to
    [from.beginning_of_day, to.end_of_day]
  end

  def check_authorization
    authorize(Account, :show?)
  end
end
