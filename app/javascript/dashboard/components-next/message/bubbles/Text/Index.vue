<script setup>
import { computed, ref } from 'vue';
import BaseBubble from 'next/message/bubbles/Base.vue';
import FormattedContent from './FormattedContent.vue';
import AttachmentChips from 'next/message/chips/AttachmentChips.vue';
import TranslationToggle from 'dashboard/components-next/message/TranslationToggle.vue';
import { MESSAGE_TYPES } from '../../constants';
import { useMessageContext } from '../../provider.js';
import { useTranslations } from 'dashboard/composables/useTranslations';
import { useMapGetter } from 'dashboard/composables/store';

const { content, attachments, contentAttributes, messageType } =
  useMessageContext();

const accountId = useMapGetter('getCurrentAccountId');

// Eltafouk: when the panel mirrored a DM that was sent as a private reply
// to a specific FB comment, it stamps the comment context onto
// content_attributes (see chatwoot-mirror.ts). Render an FB-style quoted
// reply block above the message so agents know which comment this DM
// answered, with a one-click jump back to the comment conversation.
// MessageList pipes incoming messages through useCamelCase (see
// MessageList.vue:45), so what the mirror writes as
// `eltafouk_reply_to_comment_text` arrives here as
// `eltafoukReplyToCommentText`. Read with dynamic indexing so the bundler
// can't statically eliminate either branch as dead code (a `??` chain got
// minified down to only the snake_case path in production builds).
const pickAttr = (ca, ...keys) => {
  const hit = keys.find(k => ca[k] !== undefined && ca[k] !== null);
  return hit ? ca[hit] : undefined;
};

const replyToComment = computed(() => {
  const ca = contentAttributes.value || {};
  const commentText = pickAttr(
    ca,
    'eltafoukReplyToCommentText',
    'eltafouk_reply_to_comment_text'
  );
  if (!commentText || typeof commentText !== 'string') return null;
  const convId = pickAttr(
    ca,
    'eltafoukReplyToCommentConvId',
    'eltafouk_reply_to_comment_conv_id'
  );
  const commenterName = pickAttr(
    ca,
    'eltafoukReplyToCommenterName',
    'eltafouk_reply_to_commenter_name'
  );
  return {
    text: commentText,
    convId: convId || null,
    commenterName: typeof commenterName === 'string' ? commenterName : null,
  };
});

const replyToCommentHref = computed(() => {
  const r = replyToComment.value;
  if (!r?.convId) return null;
  return `/app/accounts/${accountId.value || 1}/conversations/${r.convId}`;
});

// Held outside the template so the vue-i18n bare-string rule keeps quiet —
// the panel is Arabic-only, so plain literals are the right choice.
const replyToHeading = computed(() => {
  const r = replyToComment.value;
  if (!r) return '';
  return r.commenterName
    ? `↩ رد على كومنت ${r.commenterName}`
    : '↩ رد على كومنت العميل';
});
const replyToOpenLabel = 'افتح الكومنت ↗';
const replyToOpenTitle = 'افتح المحادثة الأصلية للكومنت في تبويبة جديدة';

const { hasTranslations, translationContent } =
  useTranslations(contentAttributes);

const renderOriginal = ref(false);

const renderContent = computed(() => {
  if (renderOriginal.value) {
    return content.value;
  }

  if (hasTranslations.value) {
    return translationContent.value;
  }

  return content.value;
});

const isTemplate = computed(() => {
  return messageType.value === MESSAGE_TYPES.TEMPLATE;
});

const isEmpty = computed(() => {
  return !content.value && !attachments.value?.length;
});

const handleSeeOriginal = () => {
  renderOriginal.value = !renderOriginal.value;
};
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="text">
    <div class="gap-3 flex flex-col">
      <div
        v-if="replyToComment"
        class="border-s-[3px] border-n-brand/60 bg-n-alpha-2 dark:bg-n-alpha-3 rounded-md ps-2 pe-2 py-1.5 -mx-1 text-[12px] leading-snug"
      >
        <div
          class="text-[10px] font-semibold uppercase tracking-wide text-n-slate-11 mb-0.5"
        >
          {{ replyToHeading }}
        </div>
        <div
          class="text-n-slate-12 line-clamp-3 whitespace-pre-line break-words"
        >
          {{ replyToComment.text }}
        </div>
        <a
          v-if="replyToCommentHref"
          :href="replyToCommentHref"
          target="_blank"
          rel="noopener noreferrer"
          class="inline-flex items-center gap-0.5 mt-1 text-[11px] font-semibold text-n-brand hover:underline"
          :title="replyToOpenTitle"
        >
          {{ replyToOpenLabel }}
        </a>
      </div>
      <span v-if="isEmpty" class="text-n-slate-11">
        {{ $t('CONVERSATION.NO_CONTENT') }}
      </span>
      <FormattedContent v-if="renderContent" :content="renderContent" />
      <TranslationToggle
        v-if="hasTranslations"
        class="-mt-3"
        :showing-original="renderOriginal"
        @toggle="handleSeeOriginal"
      />
      <AttachmentChips :attachments="attachments" class="gap-2" />
      <template v-if="isTemplate">
        <div
          v-if="contentAttributes.submittedEmail"
          class="px-2 py-1 rounded-lg bg-n-alpha-3"
        >
          {{ contentAttributes.submittedEmail }}
        </div>
      </template>
    </div>
  </BaseBubble>
</template>

<style>
p:last-child {
  margin-bottom: 0;
}
</style>
