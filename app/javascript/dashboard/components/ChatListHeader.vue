<script setup>
import { computed } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { formatNumber } from '@chatwoot/utils';
import wootConstants from 'dashboard/constants/globals';

import ConversationBasicFilter from './widgets/conversation/ConversationBasicFilter.vue';
import SwitchLayout from 'dashboard/routes/dashboard/conversation/search/SwitchLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';

const props = defineProps({
  pageTitle: { type: String, required: true },
  inbox: { type: Object, default: () => ({}) },
  hasAppliedFilters: { type: Boolean, required: true },
  hasActiveFolders: { type: Boolean, required: true },
  activeStatus: { type: String, required: true },
  isOnExpandedLayout: { type: Boolean, required: true },
  conversationStats: { type: Object, required: true },
  isListLoading: { type: Boolean, required: true },
  // Eltafouk: folder-scoped unread filter pill lives in the header instead
  // of below the title row, so it sits where the (removed) trash icon used
  // to be when a custom view is active.
  folderUnreadCount: { type: Number, default: 0 },
  folderUnreadActive: { type: Boolean, default: false },
});

const emit = defineEmits([
  'addFolders',
  'resetFilters',
  'basicFilterChange',
  'filtersModal',
  'toggleFolderUnread',
]);

const channelColor = computed(() => {
  if (!props.inbox || !props.inbox.channel_type) return '';
  const type = props.inbox.channel_type;
  const medium = props.inbox.medium;

  if (
    type === 'Channel::Whatsapp' ||
    (type === 'Channel::TwilioSms' && medium === 'whatsapp')
  ) {
    return 'color: #16a34a;';
  }
  if (type === 'Channel::FacebookPage') {
    return 'color: #2563eb;';
  }
  if (type === 'Channel::Instagram') {
    return 'color: #9333ea;';
  }
  if (type === 'Channel::Telegram') {
    return 'color: #0ea5e9;';
  }
  if (type === 'Channel::Api') {
    return 'color: #ea580c;';
  }
  if (type === 'Channel::Email') {
    return 'color: #db2777;';
  }
  return '';
});

const { uiSettings, updateUISettings } = useUISettings();

const onBasicFilterChange = (value, type) => {
  emit('basicFilterChange', value, type);
};

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return props.hasAppliedFilters || props.hasActiveFolders;
});

const allCount = computed(() => props.conversationStats?.allCount || 0);
const formattedAllCount = computed(() => formatNumber(allCount.value));

const toggleConversationLayout = () => {
  const { LAYOUT_TYPES } = wootConstants;
  const {
    conversation_display_type: conversationDisplayType = LAYOUT_TYPES.CONDENSED,
  } = uiSettings.value;
  const newViewType =
    conversationDisplayType === LAYOUT_TYPES.CONDENSED
      ? LAYOUT_TYPES.EXPANDED
      : LAYOUT_TYPES.CONDENSED;
  updateUISettings({
    conversation_display_type: newViewType,
    previously_used_conversation_display_type: newViewType,
  });
};
</script>

<template>
  <div
    class="flex items-center justify-between gap-2 px-3 h-[3.25rem]"
    :class="{
      'border-b border-n-strong': hasAppliedFiltersOrActiveFolders,
    }"
  >
    <div class="flex items-center justify-center min-w-0">
      <h1
        class="text-base font-medium truncate text-n-slate-12 flex items-center gap-1.5"
        :title="pageTitle"
      >
        <ChannelIcon
          v-if="inbox && inbox.channel_type"
          :inbox="inbox"
          class="size-4 shrink-0"
          :style="channelColor"
        />
        {{ pageTitle }}
      </h1>
      <span
        v-if="
          allCount > 0 && hasAppliedFiltersOrActiveFolders && !isListLoading
        "
        class="px-2 py-1 my-0.5 mx-1 rounded-md capitalize bg-n-slate-3 text-xxs text-n-slate-12 shrink-0"
        :title="allCount"
      >
        {{ formattedAllCount }}
      </span>
      <span
        v-if="!hasAppliedFiltersOrActiveFolders"
        class="px-2 py-1 my-0.5 mx-1 rounded-md capitalize bg-n-slate-3 text-xxs text-n-slate-12 shrink-0"
      >
        {{ $t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${activeStatus}.TEXT`) }}
      </span>
    </div>
    <div class="flex items-center gap-1">
      <template v-if="hasAppliedFilters && !hasActiveFolders">
        <div class="relative">
          <NextButton
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')"
            icon="i-lucide-save"
            slate
            xs
            faded
            @click="emit('addFolders')"
          />
          <div
            id="saveFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
        <NextButton
          v-tooltip.top-end="$t('FILTER.CLEAR_BUTTON_LABEL')"
          icon="i-lucide-circle-x"
          ruby
          faded
          xs
          @click="emit('resetFilters')"
        />
      </template>
      <template v-if="hasActiveFolders">
        <!-- Eltafouk: folder unread filter — same visual style as the inbox
             pill, sits beside the edit pencil (where the now-removed trash
             button used to be). Count comes pre-summed from ChatList based
             on the folder's inbox_id values. -->
        <button
          type="button"
          class="group/unread relative inline-flex h-6 shrink-0 items-center gap-1 whitespace-nowrap rounded-full text-[10px] font-semibold transition-all duration-200 ease-out ring-1 active:scale-[0.97]"
          :class="[
            folderUnreadActive
              ? 'bg-n-slate-12 text-white ring-n-slate-12 shadow-[0_2px_8px_rgba(0,0,0,0.18),inset_0_1px_0_rgba(255,255,255,0.18)] ps-2 pe-1.5'
              : 'bg-white text-n-slate-12 ring-n-alpha-2 hover:ring-n-slate-7 hover:bg-n-alpha-1 shadow-sm ps-2 pe-1.5',
            folderUnreadCount === 0 ? 'pe-2' : '',
          ]"
          @click="emit('toggleFolderUnread')"
        >
          <fluent-icon icon="mail-unread" size="10" />
          <span>{{ $t('CHAT_LIST.UNREAD') }}</span>
          <span
            v-if="folderUnreadCount > 0"
            class="inline-flex h-[18px] min-w-[26px] items-center justify-center rounded-full bg-[#DC2626] px-1.5 text-[10px] font-bold leading-none tabular-nums text-white animate-unread-glow ring-1 ring-inset ring-white/10"
          >
            {{ folderUnreadCount }}
          </span>
        </button>
        <div class="relative">
          <NextButton
            id="toggleConversationFilterButton"
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.EDIT.EDIT_BUTTON')"
            icon="i-lucide-pen-line"
            slate
            xs
            faded
            @click="emit('filtersModal')"
          />
          <div
            id="conversationFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
        <!-- Eltafouk: trash icon removed. The custom views in this install
             (e.g. "جميع قنوات التعليقات") are workflow-critical; a single
             accidental confirm wipes them. To delete a view, do it from the
             DB or temporarily restore this template block. -->
      </template>
      <div v-else class="relative">
        <NextButton
          id="toggleConversationFilterButton"
          v-tooltip.right="$t('FILTER.TOOLTIP_LABEL')"
          icon="i-lucide-list-filter"
          slate
          xs
          faded
          @click="emit('filtersModal')"
        />
        <div
          id="conversationFilterTeleportTarget"
          class="absolute z-50 mt-2"
          :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
        />
      </div>
      <ConversationBasicFilter
        v-if="!hasAppliedFiltersOrActiveFolders"
        :is-on-expanded-layout="isOnExpandedLayout"
        @change-filter="onBasicFilterChange"
      />
      <SwitchLayout
        :is-on-expanded-layout="isOnExpandedLayout"
        @toggle="toggleConversationLayout"
      />
    </div>
  </div>
</template>
