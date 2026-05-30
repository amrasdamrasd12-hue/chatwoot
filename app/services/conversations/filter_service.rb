class Conversations::FilterService < FilterService
  ATTRIBUTE_MODEL = 'conversation_attribute'.freeze

  def initialize(params, user, account)
    @account = account
    super(params, user)
  end

  def perform
    validate_query_operator
    @conversations = query_builder(@filters['conversations'])
    # Eltafouk: layer the same `conversation_type=unread` filter that
    # `ConversationFinder` honours on the index endpoint, so the "غير
    # مقروء" pill on saved-filter / custom-view (e.g. "جميع قنوات
    # التعليقات") behaves identically to the unfiltered list. Without
    # this the client could only narrow to unread row-by-row after the
    # full filter result paginated in, which on a 1.5K-row comments
    # folder meant 25-at-a-time infinite scroll for the same data.
    @conversations = @conversations.with_unread_incoming if @params[:conversation_type] == 'unread'

    mine_count, unassigned_count, all_count, = set_count_for_all_conversations
    assigned_count = all_count - unassigned_count

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

  # Eltafouk: this is the relation `query_builder` filters off, so it
  # must stay LEAN — no `includes`. ConversationFinder takes the same
  # approach: it filters/counts on a bare relation, then re-`includes`
  # in `conversations_base_query` right before rendering. Eager-loading
  # here causes `set_count_for_all_conversations#.select("COUNT(*)...")`
  # to raise `MissingAttributeError` for `inbox_id` etc., because the
  # `.select` strips real columns but the preloader still tries to walk
  # them when the relation materialises.
  def base_relation
    Conversations::PermissionFilterService.new(
      @account.conversations,
      @user,
      @account
    ).perform
  end

  def current_page
    @params[:page] || 1
  end

  # Eltafouk: mirror ConversationFinder#conversations_per_page — when
  # the "غير مقروء" pill is pressed the client asks for a 1000-row
  # page so the full unread set lands in one round-trip instead of
  # forty 25-row scrolls. Default stays 25 so the unfiltered
  # custom-view list keeps its progressive-load behaviour.
  def conversations_per_page
    default = ENV.fetch('CONVERSATION_RESULTS_PER_PAGE', '25').to_i
    requested = @params[:per_page].to_i
    return [requested, 1000].min if requested.positive?

    default
  end

  # Eltafouk perf: replace 3 sequential COUNTs (each re-running the
  # full filter + permission scope, plus any `with_unread_incoming`
  # EXISTS subquery) with a single FILTER aggregate pass. Same
  # semantics as ConversationFinder#set_count_for_all_conversations.
  def set_count_for_all_conversations
    result = @conversations.unscope(:order).select(
      "COUNT(*) FILTER (WHERE conversations.assignee_id = #{@user.id.to_i}) AS mine_count,
       COUNT(*) FILTER (WHERE conversations.assignee_id IS NULL) AS unassigned_count,
       COUNT(*) AS all_count"
    ).take

    [result.mine_count.to_i, result.unassigned_count.to_i, result.all_count.to_i]
  end

  def filter_config
    {
      entity: 'Conversation',
      table_name: 'conversations'
    }
  end

  def conversations
    # Eltafouk: apply the render-time includes here (same set as
    # ConversationFinder#conversations_base_query) so the partial isn't
    # firing per-row queries for inbox.channel / assignee.account_users
    # / contact.avatar. Done after `set_count_for_all_conversations`
    # so the count query never sees these includes (see base_relation
    # note above).
    @conversations.includes(
      { inbox: :channel },
      :assignee_agent_bot,
      { assignee: [{ avatar_attachment: [:blob] }, :account_users] },
      { contact: { avatar_attachment: [:blob] } },
      :team,
      :contact_inbox
    ).sort_on_last_activity_at.page(current_page).per(conversations_per_page)
  end
end
