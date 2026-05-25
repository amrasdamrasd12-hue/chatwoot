<script>
import { mapGetters } from 'vuex';
import ConversationHeader from './ConversationHeader.vue';
import DashboardAppFrame from '../DashboardApp/Frame.vue';
import EmptyState from './EmptyState/EmptyState.vue';
import MessagesView from './MessagesView.vue';

export default {
  components: {
    ConversationHeader,
    DashboardAppFrame,
    EmptyState,
    MessagesView,
  },
  props: {
    inboxId: {
      type: [Number, String],
      default: '',
      required: false,
    },
    isInboxView: {
      type: Boolean,
      default: false,
    },
    isContactPanelOpen: {
      type: Boolean,
      default: true,
    },
    isOnExpandedLayout: {
      type: Boolean,
      default: true,
    },
  },
  data() {
    return { activeIndex: 0 };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      dashboardApps: 'dashboardApps/getRecords',
    }),
    dashboardAppTabs() {
      return [
        {
          key: 'messages',
          index: 0,
          name: this.$t('CONVERSATION.DASHBOARD_APP_TAB_MESSAGES'),
        },
        ...this.dashboardApps.map((dashboardApp, index) => ({
          key: `dashboard-${dashboardApp.id}`,
          index: index + 1,
          name: dashboardApp.title,
        })),
      ];
    },
    showContactPanel() {
      return this.isContactPanelOpen && this.currentChat.id;
    },
    isCommentInbox() {
      return !!this.currentChat?.custom_attributes?.comment_id;
    },
    shouldShowFullScreenDashboardApp() {
      return this.isCommentInbox && this.dashboardApps.length > 0;
    },
  },
  watch: {
    'currentChat.inbox_id': {
      immediate: true,
      handler(inboxId) {
        if (inboxId) {
          this.$store.dispatch('inboxAssignableAgents/fetch', [inboxId]);
        }
      },
    },
    'currentChat.id'() {
      this.fetchLabels();
      this.activeIndex = 0;
    },
    // Auto-refresh comment panel iframe after agent sends outgoing message
    'currentChat.messages.length'(newLen, oldLen) {
      if (!this.shouldShowFullScreenDashboardApp) return;
      if (!newLen || newLen <= (oldLen || 0)) return;
      const messages = this.currentChat.messages || [];
      const latest = messages[messages.length - 1];
      // message_type 1 = outgoing (agent reply); 0 = incoming
      if (latest?.message_type !== 1) return;
      // Wait for Graph API to index the new comment before refreshing
      setTimeout(() => this.broadcastIframeRefresh(), 2500);
    },
  },
  mounted() {
    this.fetchLabels();
    this.$store.dispatch('dashboardApps/get');
  },
  methods: {
    fetchLabels() {
      if (!this.currentChat.id) {
        return;
      }
      this.$store.dispatch('conversationLabels/get', this.currentChat.id);
    },
    onDashboardAppTabChange(index) {
      this.activeIndex = index;
    },
    broadcastIframeRefresh() {
      const iframes = this.$el?.querySelectorAll?.('iframe');
      if (!iframes) return;
      iframes.forEach(frame => {
        frame.contentWindow?.postMessage(
          JSON.stringify({ event: 'chatwoot-dashboard-app:refresh' }),
          '*'
        );
      });
    },
  },
};
</script>

<template>
  <div
    class="conversation-details-wrap flex flex-col min-w-0 w-full bg-n-surface-1 relative"
    :class="{
      'border-l rtl:border-l-0 rtl:border-r border-n-weak': !isOnExpandedLayout,
    }"
  >
    <ConversationHeader
      v-if="currentChat.id"
      :chat="currentChat"
      :show-back-button="isOnExpandedLayout && !isInboxView"
    />
    <woot-tabs
      v-if="
        dashboardApps.length &&
        currentChat.id &&
        !shouldShowFullScreenDashboardApp
      "
      :index="activeIndex"
      class="h-10"
      @change="onDashboardAppTabChange"
    >
      <woot-tabs-item
        v-for="tab in dashboardAppTabs"
        :key="tab.key"
        :index="tab.index"
        :name="tab.name"
        :show-badge="false"
        is-compact
      />
    </woot-tabs>
    <div
      v-if="shouldShowFullScreenDashboardApp"
      class="flex h-full min-h-0 m-0 flex-col"
    >
      <div class="flex-1 min-h-0 overflow-hidden">
        <DashboardAppFrame
          :key="currentChat.id + '-comment-' + dashboardApps[0].id"
          is-visible
          :config="dashboardApps[0].content"
          :position="0"
          :current-chat="currentChat"
        />
      </div>
    </div>
    <template v-else>
      <div v-show="!activeIndex" class="flex h-full min-h-0 m-0">
        <MessagesView
          v-if="currentChat.id"
          :inbox-id="inboxId"
          :is-inbox-view="isInboxView"
        />
        <EmptyState
          v-if="!currentChat.id && !isInboxView"
          :is-on-expanded-layout="isOnExpandedLayout"
        />
        <slot />
      </div>
      <DashboardAppFrame
        v-for="(dashboardApp, index) in dashboardApps"
        v-show="activeIndex - 1 === index"
        :key="currentChat.id + '-' + dashboardApp.id"
        :is-visible="activeIndex - 1 === index"
        :config="dashboardApps[index].content"
        :position="index"
        :current-chat="currentChat"
      />
    </template>
  </div>
</template>
