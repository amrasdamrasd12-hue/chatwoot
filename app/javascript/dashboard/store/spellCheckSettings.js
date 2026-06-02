import { defineStore } from 'pinia';
import SpellCheckSettingsAPI from 'dashboard/api/spellCheckSettings';

// Eltafouk: per-account spell-check guard configuration. Cached at the
// app shell level so the ReplyBox can short-circuit the DM toggle check
// synchronously, and so the (separate) CommentThread panel can pull the
// same settings via the same store when hosted inside Chatwoot.
export const useSpellCheckSettingsStore = defineStore('spellCheckSettings', {
  state: () => ({
    settings: {
      dm_enabled: true,
      comments_enabled: false,
      long_message_strategy: 'skip',
    },
    longMessageThreshold: 500,
    uiFlags: {
      isFetching: false,
      isUpdating: false,
      loaded: false,
    },
  }),

  getters: {
    getSettings: state => state.settings,
    getLongMessageThreshold: state => state.longMessageThreshold,
    getUIFlags: state => state.uiFlags,
    isDmEnabled: state => state.settings.dm_enabled !== false,
    isCommentsEnabled: state => state.settings.comments_enabled === true,
  },

  actions: {
    async fetch() {
      if (this.uiFlags.isFetching) return;
      this.uiFlags.isFetching = true;
      try {
        const response = await SpellCheckSettingsAPI.get();
        this.settings = response.data.settings || this.settings;
        if (response.data.long_message_threshold) {
          this.longMessageThreshold = response.data.long_message_threshold;
        }
        this.uiFlags.loaded = true;
      } catch (error) {
        // Fail-open: keep defaults so the UI still works.
      } finally {
        this.uiFlags.isFetching = false;
      }
    },

    async update(patch) {
      this.uiFlags.isUpdating = true;
      try {
        const response = await SpellCheckSettingsAPI.update(patch);
        this.settings = response.data.settings || this.settings;
        if (response.data.long_message_threshold) {
          this.longMessageThreshold = response.data.long_message_threshold;
        }
      } finally {
        this.uiFlags.isUpdating = false;
      }
    },
  },
});
