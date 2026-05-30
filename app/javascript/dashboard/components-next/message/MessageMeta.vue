<script setup>
import { computed } from 'vue';
import { messageStamp } from 'shared/helpers/timeHelper';

import MessageStatus from './MessageStatus.vue';
import Icon from 'next/icon/Icon.vue';
import { useInbox } from 'dashboard/composables/useInbox';
import { useMessageContext } from './provider.js';
import { useI18n } from 'vue-i18n';

import { MESSAGE_STATUS, MESSAGE_TYPES, SENDER_TYPES } from './constants';
import { escapeHtml } from 'shared/helpers/HTMLSanitizer';

const {
  isAFacebookInbox,
  isALineChannel,
  isAPIInbox,
  isASmsInbox,
  isATelegramChannel,
  isATwilioChannel,
  isAWebWidgetInbox,
  isAWhatsAppChannel,
  isAnEmailChannel,
  isAnInstagramChannel,
  isATiktokChannel,
} = useInbox();

const {
  status,
  isPrivate,
  createdAt,
  sourceId,
  messageType,
  contentAttributes,
  sender,
} = useMessageContext();

const { t } = useI18n();

const agentNameToShow = computed(() => {
  if (!sender?.value || sender.value.type === SENDER_TYPES.AGENT_BOT) {
    return t('CONVERSATION.BOT');
  }
  if (sender.value.name) {
    return sender.value.name.split(' ')[0];
  }
  return '';
});

const showAgentName = computed(() => {
  return (
    messageType.value === MESSAGE_TYPES.OUTGOING &&
    !isPrivate.value &&
    !!agentNameToShow.value
  );
});

const readableTime = computed(() => messageStamp(createdAt.value, 'h:mm a'));

const showStatusIndicator = computed(() => {
  if (isPrivate.value) return false;
  // Don't show status for failed messages, we already show error message
  if (status.value === MESSAGE_STATUS.FAILED) return false;
  // Don't show status for deleted messages
  if (contentAttributes.value?.deleted) return false;

  if (messageType.value === MESSAGE_TYPES.OUTGOING) return true;
  if (messageType.value === MESSAGE_TYPES.TEMPLATE) return true;

  return false;
});

const isSent = computed(() => {
  if (!showStatusIndicator.value) return false;

  // Messages will be marked as sent for the Email channel if they have a source ID.
  if (isAnEmailChannel.value) return !!sourceId.value;

  if (
    isAWhatsAppChannel.value ||
    isATwilioChannel.value ||
    isAFacebookInbox.value ||
    isASmsInbox.value ||
    isATelegramChannel.value ||
    isAnInstagramChannel.value ||
    isATiktokChannel.value
  ) {
    return sourceId.value && status.value === MESSAGE_STATUS.SENT;
  }

  // All messages will be mark as sent for the Line channel, as there is no source ID.
  if (isALineChannel.value) return true;

  return false;
});

const isDelivered = computed(() => {
  if (!showStatusIndicator.value) return false;

  if (
    isAWhatsAppChannel.value ||
    isATwilioChannel.value ||
    isASmsInbox.value ||
    isAFacebookInbox.value ||
    isATiktokChannel.value
  ) {
    return sourceId.value && status.value === MESSAGE_STATUS.DELIVERED;
  }
  // All messages marked as delivered for the web widget inbox and API inbox once they are sent.
  if (isAWebWidgetInbox.value || isAPIInbox.value) {
    return status.value === MESSAGE_STATUS.SENT;
  }
  if (isALineChannel.value) {
    return status.value === MESSAGE_STATUS.DELIVERED;
  }

  return false;
});

const isRead = computed(() => {
  if (!showStatusIndicator.value) return false;

  if (
    isAWhatsAppChannel.value ||
    isATwilioChannel.value ||
    isAFacebookInbox.value ||
    isAnInstagramChannel.value ||
    isATiktokChannel.value
  ) {
    return sourceId.value && status.value === MESSAGE_STATUS.READ;
  }

  if (isAWebWidgetInbox.value || isAPIInbox.value) {
    return status.value === MESSAGE_STATUS.READ;
  }

  return false;
});

const statusToShow = computed(() => {
  if (isRead.value) return MESSAGE_STATUS.READ;
  if (isDelivered.value) return MESSAGE_STATUS.DELIVERED;
  if (isSent.value) return MESSAGE_STATUS.SENT;

  return MESSAGE_STATUS.PROGRESS;
});

// Eltafouk: outgoing messages that were relayed from FB/IG UI (the page
// replied directly on Facebook/Instagram, not from Chatwoot). The n8n
// workflow tags them with content_attributes.external_source = 'fb_page_ui'.
const isFromFbPageUi = computed(
  () => contentAttributes.value?.external_source === 'fb_page_ui'
);
const fbPageUiLabel = '↩ رد من الصفحة';
const fbPageUiTooltip =
  'هذا الرد أُرسل من واجهة فيسبوك/انستجرام مباشرة، وليس من Chatwoot';

const isEdited = computed(() => !!contentAttributes.value?.previousContent);
const editedLabel = '✎ تم التعديل';
const editedTooltip = computed(() => ({
  content: `<div dir="rtl" style="text-align:right;min-width:140px;max-width:240px"><div style="font-size:10px;font-weight:700;opacity:0.55;margin-bottom:5px;letter-spacing:0.03em">الرسالة الأصلية</div><div style="font-size:12px;line-height:1.5;word-break:break-word">${escapeHtml(contentAttributes.value?.previousContent ?? '')}</div></div>`,
  html: true,
  placement: 'top',
  triggers: ['click'],
  autoHide: true,
}));

const showReadLabel = computed(
  () => isRead.value && (isAFacebookInbox.value || isAnInstagramChannel.value)
);
</script>

<template>
  <div class="text-[11px] flex items-center gap-1">
    <div class="inline">
      <time class="inline">{{ readableTime }}</time>
    </div>
    <span v-if="showAgentName" class="inline opacity-75">
      {{ `· ${agentNameToShow}` }}
    </span>
    <span
      v-if="isFromFbPageUi"
      :title="fbPageUiTooltip"
      class="inline-flex items-center gap-0.5 rounded-md bg-[#1877F2]/10 px-1.5 py-px text-[10px] font-semibold leading-none text-[#1877F2]"
    >
      {{ fbPageUiLabel }}
    </span>
    <span
      v-if="isEdited"
      v-tooltip="editedTooltip"
      class="inline-flex items-center cursor-pointer select-none rounded-full bg-gradient-to-r from-violet-500 to-fuchsia-500 px-2 py-px text-[10px] font-bold leading-none text-white shadow-sm shadow-fuchsia-300/60 transition-all duration-150 hover:from-violet-600 hover:to-fuchsia-600 hover:shadow-fuchsia-400/70 active:scale-95"
    >
      {{ editedLabel }}
    </span>
    <Icon v-if="isPrivate" icon="i-lucide-lock-keyhole" class="size-3" />
    <MessageStatus v-if="showStatusIndicator" :status="statusToShow" />
    <span v-if="showReadLabel" class="inline opacity-75">
      {{ t('CHAT_LIST.MESSAGE_READ') }}
    </span>
  </div>
</template>
`
