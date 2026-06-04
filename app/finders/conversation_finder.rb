class ConversationFinder
  attr_reader :current_user, :current_account, :params

  DEFAULT_STATUS = 'open'.freeze
  SORT_OPTIONS = {
    'last_activity_at_asc' => %w[sort_on_last_activity_at asc],
    'last_activity_at_desc' => %w[sort_on_last_activity_at desc],
    'created_at_asc' => %w[sort_on_created_at asc],
    'created_at_desc' => %w[sort_on_created_at desc],
    'priority_asc' => %w[sort_on_priority asc],
    'priority_desc' => %w[sort_on_priority desc],
    'waiting_since_asc' => %w[sort_on_waiting_since asc],
    'waiting_since_desc' => %w[sort_on_waiting_since desc],

    # To be removed in v3.5.0
    'latest' => %w[sort_on_last_activity_at desc],
    'sort_on_created_at' => %w[sort_on_created_at asc],
    'sort_on_priority' => %w[sort_on_priority desc],
    'sort_on_waiting_since' => %w[sort_on_waiting_since asc]
  }.with_indifferent_access
  # assumptions
  # inbox_id if not given, take from all conversations, else specific to inbox
  # assignee_type if not given, take 'all'
  # conversation_status if not given, take 'open'

  # response of this class will be of type
  # {conversations: [array of conversations], count: {open: count, resolved: count}}

  # params
  # assignee_type, inbox_id, :status

  def initialize(current_user, params)
    @current_user = current_user
    @current_account = current_user.account
    @is_admin = current_account.account_users.find_by(user_id: current_user.id)&.administrator?
    @params = params
  end

  def perform
    set_up

    mine_count, unassigned_count, all_count, = set_count_for_all_conversations
    assigned_count = all_count - unassigned_count

    filter_by_assignee_type

    {
      conversations: conversations,
      count: {
        mine_count: mine_count,
        assigned_count: assigned_count,
        unassigned_count: unassigned_count,
        all_count: all_count
      }
    }
  end

  private

  def set_up
    return set_up_mentions if params[:conversation_type] == 'mention'

    set_inboxes
    set_team
    set_assignee_type

    find_all_conversations
    filter_by_status unless params[:q]
    filter_by_team
    filter_by_labels
    filter_by_query
    filter_by_source_id
  end

  # The Mentions folder is built directly from the current user's mention
  # records — independent of inbox assignment, conversation status, and
  # assignee tab. Access is already gated when the mention is created
  # (Messages::MentionService#filter_mentioned_ids_by_inbox), so no further
  # inbox/permission/status filtering is applied here: a mention in a
  # resolved conversation or an inbox the agent no longer owns still shows.
  def set_up_mentions
    set_team
    @assignee_type = 'all'

    conversation_ids = current_account.mentions.where(user: current_user).pluck(:conversation_id)
    @conversations = current_account.conversations.where(id: conversation_ids)

    filter_by_team
    filter_by_labels
    filter_by_query
  end

  def set_inboxes
    @inbox_ids = if params[:inbox_id]
                   @current_user.assigned_inboxes.where(id: params[:inbox_id])
                 else
                   # Aggregate views (All / Mentions / Unattended) exclude comment inboxes —
                   # those live in their own sidebar section and are reached via explicit inbox_id.
                   @current_user.assigned_inboxes.non_comment_inboxes.pluck(:id)
                 end
  end

  def set_assignee_type
    @assignee_type = params[:assignee_type]
  end

  def set_team
    @team = current_account.teams.find(params[:team_id]) if params[:team_id]
  end

  def find_conversation_by_inbox
    @conversations = current_account.conversations.where(inbox_id: @inbox_ids)
  end

  def find_all_conversations
    find_conversation_by_inbox
    # Apply permission-based filtering
    @conversations = Conversations::PermissionFilterService.new(
      @conversations,
      current_user,
      current_account
    ).perform
    filter_by_conversation_type if params[:conversation_type]
    @conversations
  end

  def filter_by_assignee_type
    case @assignee_type
    when 'me'
      @conversations = @conversations.assigned_to(current_user)
    when 'unassigned'
      @conversations = @conversations.unassigned
    when 'assigned'
      @conversations = @conversations.assigned
    end
    @conversations
  end

  def filter_by_conversation_type
    case @params[:conversation_type]
    when 'participating'
      @conversations = current_user.participating_conversations.where(account_id: current_account.id)
    when 'unattended'
      @conversations = @conversations.unattended
    when 'unread'
      # Eltafouk: matches the exact criteria the sidebar's per-inbox
      # unread badge uses (incoming messages newer than the agent's
      # last_seen). Used by the chat-list "غير مقروء" filter pill so
      # the post-filter list matches the badge count by construction.
      @conversations = @conversations.with_unread_incoming
    end
    @conversations
  end

  def filter_by_query
    return unless params[:q]

    allowed_message_types = [Message.message_types[:incoming], Message.message_types[:outgoing]]
    @conversations = conversations.joins(:messages).where('messages.content ILIKE :search', search: "%#{params[:q]}%")
                                  .where(messages: { message_type: allowed_message_types }).includes(:messages)
                                  .where('messages.content ILIKE :search', search: "%#{params[:q]}%")
                                  .where(messages: { message_type: allowed_message_types })
  end

  def filter_by_status
    return if params[:status] == 'all'

    @conversations = @conversations.where(status: params[:status] || DEFAULT_STATUS)
  end

  def filter_by_team
    return unless @team

    @conversations = @conversations.where(team: @team)
  end

  def filter_by_labels
    return unless params[:labels]

    @conversations = @conversations.tagged_with(params[:labels], any: true)
  end

  def filter_by_source_id
    return unless params[:source_id]

    @conversations = @conversations.joins(:contact_inbox)
    @conversations = @conversations.where(contact_inboxes: { source_id: params[:source_id] })
  end

  def set_count_for_all_conversations
    # Eltafouk perf: collapse 3 sequential COUNTs into a single aggregate
    # pass. Each prior COUNT re-ran the EXISTS subquery (e.g.
    # `with_unread_incoming`) over the full conversations table — ~1.5s
    # cold each. Postgres `FILTER` lets us compute mine/unassigned/all
    # in one go while preserving identical filter semantics
    # (assignee_id = current_user / assignee_id IS NULL / no filter).
    result = @conversations.unscope(:order).select(
      "COUNT(*) FILTER (WHERE conversations.assignee_id = #{current_user.id.to_i}) AS mine_count,
       COUNT(*) FILTER (WHERE conversations.assignee_id IS NULL) AS unassigned_count,
       COUNT(*) AS all_count"
    ).take

    [result.mine_count.to_i, result.unassigned_count.to_i, result.all_count.to_i]
  end

  def current_page
    params[:page] || 1
  end

  # Eltafouk: when the "غير مقروء" pill is pressed, the client asks for
  # all unread rows in a single request via per_page. Capped at 1000 so
  # a runaway/misconfigured client can't ask for tens of thousands of
  # rows and blow up the JSON serializer or the browser. Default stays
  # the historical env-controlled 25 so the unfiltered list keeps its
  # progressive-load behaviour.
  def conversations_per_page
    default = ENV.fetch('CONVERSATION_RESULTS_PER_PAGE', '25').to_i
    requested = params[:per_page].to_i
    return [requested, 1000].min if requested.positive?

    default
  end

  def conversations_base_query
    # Eltafouk: drop `:taggings` — labels are read from the cached
    # column `cached_label_list_array`, so eager-loading taggings is
    # pure waste. Add `:account_users` on assignee (needed by
    # `User#current_account_user` inside `_agent.json.jbuilder` for
    # availability_status) and `:channel` on inbox (needed by
    # `MessageWindowService` to decide can_reply? on the 24h-window
    # channels). Both were silent per-row queries on the 505-row list.
    @conversations.includes(
      { inbox: :channel }, :assignee_agent_bot,
      { assignee: [{ avatar_attachment: [:blob] }, :account_users] },
      { contact: { avatar_attachment: [:blob] } },
      :team, :contact_inbox
    )
  end

  def conversations
    @conversations = conversations_base_query

    sort_by, sort_order = SORT_OPTIONS[params[:sort_by]] || SORT_OPTIONS['last_activity_at_desc']
    @conversations = @conversations.send(sort_by, sort_order)

    if params[:updated_within].present?
      @conversations.where('conversations.updated_at > ?', Time.zone.now - params[:updated_within].to_i.seconds)
    else
      @conversations.page(current_page).per(conversations_per_page)
    end
  end
end
ConversationFinder.prepend_mod_with('ConversationFinder')
