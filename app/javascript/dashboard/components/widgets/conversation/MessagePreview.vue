<script>
import { MESSAGE_TYPE } from 'widget/helpers/constants';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { ATTACHMENT_ICONS } from 'shared/constants/messages';

export default {
  name: 'MessagePreview',
  props: {
    message: {
      type: Object,
      required: true,
    },
    showMessageType: {
      type: Boolean,
      default: true,
    },
    defaultEmptyMessage: {
      type: String,
      default: '',
    },
  },
  setup() {
    const { getPlainText } = useMessageFormatter();
    return {
      getPlainText,
    };
  },
  computed: {
    messageByAgent() {
      const { message_type: messageType } = this.message;
      return messageType === MESSAGE_TYPE.OUTGOING;
    },
    isMessageAnActivity() {
      const { message_type: messageType } = this.message;
      return messageType === MESSAGE_TYPE.ACTIVITY;
    },
    isMessagePrivate() {
      const { private: isPrivate } = this.message;
      return isPrivate;
    },
    isFromFbPageUi() {
      // Eltafouk: outgoing relay messages tagged by n8n WF1 / backfill —
      // the page replied directly on FB/IG UI instead of via Chatwoot.
      const ca = this.message?.content_attributes;
      // content_attributes may be a json string scalar or a parsed object
      // depending on the codepath that wrote it; handle both shapes.
      if (typeof ca === 'string') {
        try {
          return JSON.parse(ca)?.external_source === 'fb_page_ui';
        } catch (e) {
          return false;
        }
      }
      return ca?.external_source === 'fb_page_ui';
    },
    parsedLastMessage() {
      const { content_attributes: contentAttributes } = this.message;
      const { email: { subject } = {} } = contentAttributes || {};
      const raw = this.getPlainText(subject || this.message.content);
      // Eltafouk: strip the '📎 البوست: <url>' suffix that n8n appends to comment messages.
      // Also strip the '[رد من <name>]:' prefix on nested-reply messages — the
      // commenter's name is already surfaced as the card's title in
      // ConversationCard, so repeating it in the preview is noise.
      return raw
        .replace(/\s*[\u{1F4CE}\u{1F517}]\s*البوست:[\s\S]*$/u, '')
        .replace(/^\[رد من\s+[^\]]+\]\s*:\s*/u, '')
        .trim();
    },
    lastMessageFileType() {
      const [{ file_type: fileType } = {}] = this.message.attachments;
      return fileType;
    },
    attachmentIcon() {
      return ATTACHMENT_ICONS[this.lastMessageFileType];
    },
    attachmentMessageContent() {
      return `CHAT_LIST.ATTACHMENTS.${this.lastMessageFileType}.CONTENT`;
    },
    isMessageSticker() {
      return this.message && this.message.content_type === 'sticker';
    },
    messageDeliveryStatus() {
      // Chatwoot message status: sent=0, delivered=1, read=2, failed=3
      return this.message?.status || 'sent';
    },
    isDelivered() {
      return this.messageDeliveryStatus === 'delivered';
    },
    isRead() {
      return this.messageDeliveryStatus === 'read';
    },
    isFailed() {
      return this.messageDeliveryStatus === 'failed';
    },
    tickColor() {
      if (this.isRead) return '#53bdeb';
      return '#8696a0';
    },
    fbPageUiLabel() {
      return '↩ من الصفحة';
    },
    fbPageUiTooltip() {
      return 'هذا الرد أُرسل من واجهة فيسبوك/انستجرام مباشرة، وليس من Chatwoot';
    },
  },
};
</script>

<template>
  <div
    class="overflow-hidden text-ellipsis whitespace-nowrap font-bubble-text [unicode-bidi:plaintext]"
    dir="auto"
  >
    <template v-if="showMessageType">
      <fluent-icon
        v-if="isMessagePrivate"
        size="16"
        class="-mt-0.5 align-middle text-n-slate-11 inline-block"
        icon="lock-closed"
      />
      <!-- Eltafouk: delivery ticks (sent/delivered/read/failed) only make
           sense for DMs. A Facebook/Instagram comment is public the moment
           it posts; there's no per-recipient delivery state. Outgoing
           relay messages on the comments inbox carry no real status either —
           the Chatwoot message is just an echo of what n8n already sent
           to FB. Hide the icons entirely for them. -->
      <template v-else-if="messageByAgent && !isFromFbPageUi">
        <svg
          v-if="isFailed"
          class="-mt-0.5 align-middle inline-block"
          width="14"
          height="14"
          viewBox="0 0 14 14"
        >
          <circle
            cx="7"
            cy="7"
            r="6"
            fill="none"
            stroke="#e74c3c"
            stroke-width="1.5"
          />
          <path
            d="M7 4v3.5M7 9v.5"
            stroke="#e74c3c"
            stroke-width="1.5"
            stroke-linecap="round"
          />
        </svg>
        <svg
          v-else-if="isRead || isDelivered"
          class="-mt-0.5 align-middle inline-block"
          width="18"
          height="12"
          viewBox="0 0 18 12"
        >
          <path
            d="M1.5 6.5L5 10L12.5 1.5"
            fill="none"
            :stroke="tickColor"
            stroke-width="1.6"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <path
            d="M6 6.5L9.5 10L17 1.5"
            fill="none"
            :stroke="tickColor"
            stroke-width="1.6"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
        <svg
          v-else
          class="-mt-0.5 align-middle inline-block"
          width="14"
          height="12"
          viewBox="0 0 14 12"
        >
          <path
            d="M1.5 6.5L5 10L12.5 1.5"
            fill="none"
            stroke="#8696a0"
            stroke-width="1.6"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </template>
      <fluent-icon
        v-else-if="isMessageAnActivity"
        size="16"
        class="-mt-0.5 align-middle text-n-slate-11 inline-block"
        icon="info"
      />
    </template>
    <span
      v-if="isFromFbPageUi"
      :title="fbPageUiTooltip"
      class="inline-flex items-center align-middle gap-0.5 rounded-md bg-[#1877F2]/10 px-1 py-px ltr:mr-1 rtl:ml-1 text-[9px] font-semibold leading-none text-[#1877F2]"
    >
      {{ fbPageUiLabel }}
    </span>
    <span v-if="message.content && isMessageSticker">
      <fluent-icon
        size="16"
        class="-mt-0.5 align-middle inline-block text-n-slate-11"
        icon="image"
      />
      {{ $t('CHAT_LIST.ATTACHMENTS.image.CONTENT') }}
    </span>
    <span v-else-if="message.content">
      {{ parsedLastMessage }}
    </span>
    <span v-else-if="message.attachments">
      <fluent-icon
        v-if="attachmentIcon && showMessageType"
        size="16"
        class="-mt-0.5 align-middle inline-block text-n-slate-11"
        :icon="attachmentIcon"
      />
      {{ $t(`${attachmentMessageContent}`) }}
    </span>
    <span v-else>
      {{ defaultEmptyMessage || $t('CHAT_LIST.NO_CONTENT') }}
    </span>
  </div>
</template>
