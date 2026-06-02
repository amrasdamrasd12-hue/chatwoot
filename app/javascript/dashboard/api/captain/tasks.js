/* global axios */
import ApiClient from '../ApiClient';

/**
 * A client for the Captain Tasks API.
 * @extends ApiClient
 */
class TasksAPI extends ApiClient {
  /**
   * Creates a new TasksAPI instance.
   */
  constructor() {
    super('captain/tasks', { accountScoped: true });
  }

  /**
   * Rewrites content with a specific operation.
   * @param {Object} options - The rewrite options.
   * @param {string} options.content - The content to rewrite.
   * @param {string} options.operation - The rewrite operation (fix_spelling_grammar, casual, professional, etc).
   * @param {string} [options.conversationId] - The conversation ID for context (required for 'improve').
   * @param {AbortSignal} [signal] - AbortSignal to cancel the request.
   * @returns {Promise} A promise that resolves with the rewritten content.
   */
  rewrite({ content, operation, conversationId }, signal) {
    return axios.post(
      `${this.url}/rewrite`,
      {
        content,
        operation,
        conversation_display_id: conversationId,
      },
      { signal }
    );
  }

  /**
   * Summarizes a conversation.
   * @param {string} conversationId - The conversation ID to summarize.
   * @param {AbortSignal} [signal] - AbortSignal to cancel the request.
   * @returns {Promise} A promise that resolves with the summary.
   */
  summarize(conversationId, signal) {
    return axios.post(
      `${this.url}/summarize`,
      {
        conversation_display_id: conversationId,
      },
      { signal }
    );
  }

  /**
   * Gets a reply suggestion for a conversation.
   * @param {string} conversationId - The conversation ID.
   * @param {AbortSignal} [signal] - AbortSignal to cancel the request.
   * @returns {Promise} A promise that resolves with the reply suggestion.
   */
  replySuggestion(conversationId, signal) {
    return axios.post(
      `${this.url}/reply_suggestion`,
      {
        conversation_display_id: conversationId,
      },
      { signal }
    );
  }

  /**
   * Gets label suggestions for a conversation.
   * @param {string} conversationId - The conversation ID.
   * @param {AbortSignal} [signal] - AbortSignal to cancel the request.
   * @returns {Promise} A promise that resolves with label suggestions.
   */
  labelSuggestion(conversationId, signal) {
    return axios.post(
      `${this.url}/label_suggestion`,
      {
        conversation_display_id: conversationId,
      },
      { signal }
    );
  }

  /**
   * Sends a follow-up message to continue refining a previous task result.
   * @param {Object} options - The follow-up options.
   * @param {Object} options.followUpContext - The follow-up context from a previous task.
   * @param {string} options.message - The follow-up message/request from the user.
   * @param {string} [options.conversationId] - The conversation ID for Langfuse session tracking.
   * @param {AbortSignal} [signal] - AbortSignal to cancel the request.
   * @returns {Promise} A promise that resolves with the follow-up response and updated follow-up context.
   */
  followUp({ followUpContext, message, conversationId }, signal) {
    return axios.post(
      `${this.url}/follow_up`,
      {
        follow_up_context: followUpContext,
        message,
        conversation_display_id: conversationId,
      },
      { signal }
    );
  }

  /**
   * Eltafouk: stateless pre-send spell/grammar check. Returns
   * { has_errors, original, corrected, fixes, model_used } and writes NO
   * audit row — the outcome is persisted later via spellCheckDecisionCreate
   * once the agent finalises the modal (or on a clean send). The `surface`
   * hint ("dm" / "comments") lets the backend short-circuit when the
   * matching toggle is off in the per-account settings — that way a
   * disabled surface costs zero LLM tokens.
   */
  spellCheck(content, surface, conversationDisplayId, signal) {
    return axios.post(
      `${this.url}/spell_check`,
      {
        content,
        surface: surface || 'dm',
        conversation_display_id: conversationDisplayId,
      },
      { signal }
    );
  }

  /**
   * Eltafouk: fire-and-forget create of the spell-check audit event at
   * decision time (Solution 3). No event_id — the backend create branch
   * builds the row from the decision plus the snapshot returned by
   * /spell_check. Used by the modal callbacks (corrected / sent_original /
   * edited) and the clean-send path (no_errors_send). Category is recomputed
   * server-side; user_id is always the current agent. Never await before the
   * actual send — call with .catch(() => {}).
   */
  spellCheckDecisionCreate({
    decision,
    original,
    corrected,
    fixes,
    surface,
    conversationDisplayId,
    modelUsed,
    editedText,
  }) {
    return axios.post(`${this.url}/spell_check_decision`, {
      decision,
      original,
      corrected,
      fixes,
      surface: surface || 'dm',
      conversation_display_id: conversationDisplayId,
      model_used: modelUsed,
      // Only sent for 'edited' — the agent's final text vs the suggestion.
      edited_text: editedText,
    });
  }

  /**
   * Eltafouk: LEGACY fire-and-forget update of a pre-created spell-check
   * event by id. Kept for rolling-deploy safety only — current clients use
   * the create-at-decision path (spellCheckDecisionCreate). Removed once no
   * client still carries an event_id.
   */
  spellCheckDecision(eventId, decision) {
    if (!eventId) return Promise.resolve();
    return axios.post(`${this.url}/spell_check_decision`, {
      event_id: eventId,
      decision,
    });
  }
}

export default new TasksAPI();
