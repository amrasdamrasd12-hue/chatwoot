/* global axios */
import ApiClient from './ApiClient';

// Eltafouk: aggregated per-agent spell-check audit data for the
// reports page. Accepts ISO date range (since/until) and an optional
// list of user_ids to scope the rollup.
class SpellCheckReports extends ApiClient {
  constructor() {
    super('spell_check_reports', { accountScoped: true });
  }

  fetch({ since, until, userIds } = {}) {
    const params = {};
    if (since) params.since = since;
    if (until) params.until = until;
    if (userIds && userIds.length) params.user_ids = userIds;
    return axios.get(this.url, { params });
  }
}

export default new SpellCheckReports();
