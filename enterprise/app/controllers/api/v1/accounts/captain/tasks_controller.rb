class Api::V1::Accounts::Captain::TasksController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  # Decisions that represent a finalised modal choice — once recorded, a stray
  # late 'pending' write (e.g. a re-opened modal) must not overwrite them.
  FINAL_DECISIONS = %w[corrected sent_original edited].freeze

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
    surface = params[:surface].to_s.presence || 'dm'
    if surface_disabled?(surface)
      render json: { has_errors: false, original: params[:content].to_s, corrected: params[:content].to_s, fixes: [] }
      return
    end

    conversation_id = resolve_conversation_id
    inbox_id = resolve_inbox_id(conversation_id)

    result = Captain::SpellCheckService.new(
      account: Current.account,
      content: params[:content].to_s,
      user_id: Current.user&.id,
      conversation_id: conversation_id,
      inbox_id: inbox_id,
      surface: surface
    ).perform

    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: {
        has_errors: result[:has_errors] ? true : false,
        original: result[:original].to_s,
        corrected: result[:corrected].to_s,
        fixes: Array(result[:fixes]),
        event_id: result[:event_id]
      }
    end
  end

  # Eltafouk: the modal callbacks (تصحيح وإرسال / إرسال كما هو / تعديل
  # النص) finalise the decision row created when the spell-check API was
  # called. Fire-and-forget from the client side so a slow audit-log
  # write never delays the actual customer reply.
  def spell_check_decision
    event = Current.account.spell_check_events.find_by(id: params[:event_id])
    # Block missing events and accidental cross-account writes (the policy
    # already gates the controller; this guards the per-agent session row).
    return head :ok unless event && event_writable_by_current_user?(event)

    decision = normalized_decision
    # A final decision (corrected/sent_original/edited) must always persist —
    # the modal PATCHes 'pending' on open, so by the time the agent picks a
    # final decision the event already holds 'pending'. Only block the reverse:
    # a stray late 'pending' must not clobber an already-final decision.
    event.update(decision: decision) unless clobbers_final_decision?(event, decision)
    head :ok
  end

  private

  def event_writable_by_current_user?(event)
    event.user_id.blank? || event.user_id == Current.user&.id
  end

  def normalized_decision
    decision = params[:decision].to_s
    SpellCheckEvent::DECISIONS.include?(decision) ? decision : 'unknown'
  end

  def clobbers_final_decision?(event, decision)
    decision == 'pending' && FINAL_DECISIONS.include?(event.decision)
  end

  def surface_disabled?(surface)
    settings = Current.account.spell_check_settings.to_h.stringify_keys
    case surface
    when 'comments' then settings['comments_enabled'] == false
    when 'dm' then settings['dm_enabled'] == false
    else false  # unknown surface — never block, default behaviour
    end
  end

  def resolve_conversation_id
    display_id = params[:conversation_display_id].presence
    return nil unless display_id

    Current.account.conversations.find_by(display_id: display_id)&.id
  end

  def resolve_inbox_id(conversation_id)
    return nil unless conversation_id

    Current.account.conversations.where(id: conversation_id).pick(:inbox_id)
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
