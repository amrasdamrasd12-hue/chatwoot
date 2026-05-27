import types from '../mutation-types';
import ConversationApi from '../../api/inbox/conversation';
import { debounce } from '@chatwoot/utils';

const state = {
  mineCount: 0,
  unAssignedCount: 0,
  allCount: 0,
  // Eltafouk: parallel slot fed by `getUnread` — exact same /meta endpoint
  // but with conversation_type=unread layered onto whatever scope (inbox,
  // team, label) is currently in play. Drives the "غير مقروء" pill badge
  // so it always reflects the same number the tab counters would land on
  // after a click; previously the badge was summed from a different API
  // (inboxes/unattended_counts) which doesn't filter by status=open, and
  // they drifted by 1-2 for non-open-but-unread conversations.
  unreadMineCount: 0,
  unreadUnAssignedCount: 0,
  unreadAllCount: 0,
};

export const getters = {
  getStats: $state => $state,
};

// Create a debounced version of the actual API call function
const fetchMetaData = async (commit, params) => {
  try {
    const response = await ConversationApi.meta(params);
    const {
      data: { meta },
    } = response;
    commit(types.SET_CONV_TAB_META, meta);
  } catch (error) {
    // ignore
  }
};

const fetchUnreadMetaData = async (commit, params) => {
  try {
    const response = await ConversationApi.meta({
      ...params,
      conversation_type: 'unread',
    });
    const {
      data: { meta },
    } = response;
    commit(types.SET_CONV_UNREAD_META, meta);
  } catch (error) {
    // ignore
  }
};

const debouncedFetchMetaData = debounce(fetchMetaData, 500, false, 1500);
const longDebouncedFetchMetaData = debounce(fetchMetaData, 5000, false, 10000);
const superLongDebouncedFetchMetaData = debounce(
  fetchMetaData,
  10000,
  false,
  20000
);

const debouncedFetchUnreadMetaData = debounce(
  fetchUnreadMetaData,
  500,
  false,
  1500
);

export const actions = {
  get: async ({ commit, state: $state }, params) => {
    if ($state.allCount > 5000) {
      superLongDebouncedFetchMetaData(commit, params);
    } else if ($state.allCount > 100) {
      longDebouncedFetchMetaData(commit, params);
    } else {
      debouncedFetchMetaData(commit, params);
    }
  },
  // Eltafouk: companion to `get`. Always force conversation_type=unread
  // on the params so the badge's count source matches exactly what the
  // backend's unread filter would return — no semantic gap with the tab.
  getUnread: async ({ commit }, params) => {
    debouncedFetchUnreadMetaData(commit, params);
  },
  set({ commit }, meta) {
    commit(types.SET_CONV_TAB_META, meta);
  },
};

export const mutations = {
  [types.SET_CONV_TAB_META](
    $state,
    {
      mine_count: mineCount,
      unassigned_count: unAssignedCount,
      all_count: allCount,
    } = {}
  ) {
    $state.mineCount = mineCount;
    $state.allCount = allCount;
    $state.unAssignedCount = unAssignedCount;
    $state.updatedOn = new Date();
  },
  [types.SET_CONV_UNREAD_META](
    $state,
    {
      mine_count: mineCount,
      unassigned_count: unAssignedCount,
      all_count: allCount,
    } = {}
  ) {
    $state.unreadMineCount = mineCount;
    $state.unreadAllCount = allCount;
    $state.unreadUnAssignedCount = unAssignedCount;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
