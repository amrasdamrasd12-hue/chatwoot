/* global axios */
import ApiClient from './ApiClient';

// Eltafouk: per-agent activity report (DM + comment replies, channels,
// detected shift, in-shift response time). Accepts an ISO date range
// (since/until, Africa/Cairo) plus optional user_ids / inbox_ids scoping.
class AgentActivityReports extends ApiClient {
  constructor() {
    super('agent_activity_reports', { accountScoped: true });
  }

  fetch({ since, until, userIds, inboxIds } = {}) {
    const params = {};
    if (since) params.since = since;
    if (until) params.until = until;
    if (userIds && userIds.length) params.user_ids = userIds;
    if (inboxIds && inboxIds.length) params.inbox_ids = inboxIds;
    return axios.get(this.url, { params });
  }
}

export default new AgentActivityReports();
