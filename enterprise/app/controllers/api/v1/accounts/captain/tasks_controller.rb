class Api::V1::Accounts::Captain::TasksController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def rewrite
    result = Captain::RewriteService.new(
      account: Current.account,
      content: params[:content],
      operation: params[:operation],
      conversation_display_id: params[:conversation_display_id]
    ).perform

    render_result(result)
  end

  def summarize
    result = Captain::SummaryService.new(
      account: Current.account,
      conversation_display_id: params[:conversation_display_id]
    ).perform

    render_result(result)
  end

  def reply_suggestion
    result = Captain::ReplySuggestionService.new(
      account: Current.account,
      conversation_display_id: params[:conversation_display_id],
      user: Current.user
    ).perform

    render_result(result)
  end

  def label_suggestion
    result = Captain::LabelSuggestionService.new(
      account: Current.account,
      conversation_display_id: params[:conversation_display_id]
    ).perform

    render_result(result)
  end

  def follow_up
    result = Captain::FollowUpService.new(
      account: Current.account,
      follow_up_context: params[:follow_up_context]&.to_unsafe_h,
      user_message: params[:message],
      conversation_display_id: params[:conversation_display_id]
    ).perform

    render_result(result)
  end

  # Eltafouk: pre-send spell-check gate. Called by the dashboard reply box
  # before every outgoing send so the agent can confirm a corrected version
  # when the model finds spelling/grammar issues.
  #
  # We bypass `render_result` here because that helper only knows about the
  # generic `{ message: ... }` task response shape — it would silently drop
  # the `has_errors` / `original` / `corrected` fields the reply box needs
  # to decide whether to open the modal.
  #
  # `surface` is a free-form caller hint ("dm" / "comments") so the
  # account-level toggle can disable spell-check per surface without the
  # caller having to inspect settings itself.
  def spell_check
    surface = params[:surface].to_s
    if surface_disabled?(surface)
      render json: { has_errors: false, original: params[:content].to_s, corrected: params[:content].to_s, fixes: [] }
      return
    end

    result = Captain::SpellCheckService.new(
      account: Current.account,
      content: params[:content].to_s
    ).perform

    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: {
        has_errors: result[:has_errors] ? true : false,
        original: result[:original].to_s,
        corrected: result[:corrected].to_s,
        fixes: Array(result[:fixes])
      }
    end
  end

  private

  def surface_disabled?(surface)
    settings = Current.account.spell_check_settings.to_h.stringify_keys
    case surface
    when 'comments' then settings['comments_enabled'] == false
    when 'dm' then settings['dm_enabled'] == false
    else false  # unknown surface — never block, default behaviour
    end
  end

  def render_result(result)
    if result.nil?
      render json: { message: nil }
    elsif result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      response_data = { message: result[:message] }
      response_data[:follow_up_context] = result[:follow_up_context] if result[:follow_up_context]
      render json: response_data
    end
  end

  def check_authorization
    authorize(:'captain/tasks')
  end
end
