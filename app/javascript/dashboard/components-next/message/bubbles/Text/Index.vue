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
const replyEyebrowLabel = 'رد على كومنت';
const replyFallbackName = 'العميل';
const replyToOpenTitle = 'افتح المحادثة الأصلية للكومنت في تبويبة جديدة';

// Pull a single grapheme out of the commenter's name for the avatar
// medallion. Arabic names commonly start with letters that are a single
// codepoint, so charAt() is correct here. Fall back to a quotation glyph
// when the name is missing — the medallion still looks intentional rather
// than appearing as an empty circle.
const replyCommenterInitial = computed(() => {
  const name = replyToComment.value?.commenterName;
  const ch = name?.trim?.()?.charAt(0);
  return ch || '"';
});
const replyCommenterDisplay = computed(
  () => replyToComment.value?.commenterName || replyFallbackName
);
// Curly quotation glyphs are held in JS so the bare-string lint rule keeps
// quiet — they're decoration, not translatable copy.
const replyQuoteOpenGlyph = '“';
const replyQuoteCloseGlyph = '”';
const replyEyebrowGlyph = '↩';

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
      <component
        :is="replyToCommentHref ? 'a' : 'div'"
        v-if="replyToComment"
        :href="replyToCommentHref || undefined"
        :target="replyToCommentHref ? '_blank' : undefined"
        :rel="replyToCommentHref ? 'noopener noreferrer' : undefined"
        :title="replyToCommentHref ? replyToOpenTitle : undefined"
        class="group/quote relative flex items-stretch gap-3 -mx-1 -mt-1 mb-1 rounded-2xl bg-white text-slate-900 ring-1 ring-black/5 px-3 py-2.5 shadow-[0_4px_14px_-6px_rgba(15,23,42,0.35),0_2px_4px_-2px_rgba(15,23,42,0.2)] transition-all duration-150 ease-out hover:-translate-y-px hover:shadow-[0_6px_18px_-6px_rgba(15,23,42,0.45),0_2px_6px_-2px_rgba(15,23,42,0.25)]"
      >
        <span
          aria-hidden="true"
          class="flex-shrink-0 self-center inline-flex size-9 items-center justify-center rounded-full bg-slate-900 text-[14px] font-bold leading-none text-white shadow-[inset_0_-1px_0_rgba(0,0,0,0.25),inset_0_1px_0_rgba(255,255,255,0.12)]"
        >
          {{ replyCommenterInitial }}
        </span>
        <span
          class="flex min-w-0 flex-1 flex-col gap-0.5 justify-center py-0.5"
        >
          <span
            class="flex items-baseline gap-1.5 text-[10px] font-semibold uppercase tracking-[0.08em] text-slate-500"
          >
            <span aria-hidden="true" class="text-slate-400">{{
              replyEyebrowGlyph
            }}</span>
            <span>{{ replyEyebrowLabel }}</span>
            <span
              class="truncate text-[12px] font-bold normal-case tracking-normal text-slate-900"
              :title="replyCommenterDisplay"
            >
              {{ replyCommenterDisplay }}
            </span>
          </span>
          <span
            class="text-[14px] font-medium leading-snug text-slate-800 line-clamp-2 break-words"
          >
            <span
              aria-hidden="true"
              class="me-0.5 inline-block font-serif text-[18px] leading-none text-slate-300 align-baseline"
              >{{ replyQuoteOpenGlyph }}</span
            >{{ replyToComment.text
            }}<span
              aria-hidden="true"
              class="ms-0.5 inline-block font-serif text-[18px] leading-none text-slate-300 align-baseline"
              >{{ replyQuoteCloseGlyph }}</span
            >
          </span>
        </span>
        <span
          v-if="replyToCommentHref"
          aria-hidden="true"
          class="flex-shrink-0 self-center inline-flex size-7 items-center justify-center rounded-full bg-slate-100 text-slate-600 ring-1 ring-slate-200 transition-all duration-150 ease-out group-hover/quote:bg-slate-900 group-hover/quote:text-white group-hover/quote:ring-slate-900 group-hover/quote:translate-x-[-2px] rtl:group-hover/quote:translate-x-[2px]"
        >
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="size-3.5 rtl:-scale-x-100"
          >
            <path d="M5 12h14M13 5l7 7-7 7" />
          </svg>
        </span>
      </component>
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
