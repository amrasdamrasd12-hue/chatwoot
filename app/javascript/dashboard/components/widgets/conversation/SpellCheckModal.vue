<script setup>
import { ref, computed, watch } from 'vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

// Eltafouk: pre-send spell/grammar guard. Renders a side-by-side diff of the
// agent's original draft vs the AI-corrected version. The corrected version
// is the primary action; sending the original is gated behind an explicit
// "I'm sure" confirmation step so it can't be muscle-memoried away.
const props = defineProps({
  show: { type: Boolean, default: false },
  original: { type: String, default: '' },
  corrected: { type: String, default: '' },
});

const emit = defineEmits([
  'update:show',
  'sendCorrected',
  'sendOriginal',
  'edit',
]);

const dialogRef = ref(null);
const confirmOriginal = ref(false);

watch(
  () => props.show,
  newVal => {
    if (newVal) {
      confirmOriginal.value = false;
      dialogRef.value?.open();
    } else {
      dialogRef.value?.close();
    }
  }
);

const close = () => {
  emit('update:show', false);
};
const onEdit = () => {
  emit('edit');
  close();
};
const onSendCorrected = () => {
  emit('sendCorrected', props.corrected);
  close();
};
const onSendOriginalClick = () => {
  if (!confirmOriginal.value) {
    confirmOriginal.value = true;
    return;
  }
  emit('sendOriginal', props.original);
  close();
};

// Word-level diff. Coloring tokens that differ between the two strings —
// not a true LCS diff, but good enough to draw attention to the changed
// words in a customer-support message (typically a sentence or two).
const tokenize = text => (text || '').split(/(\s+)/);

const originalTokens = computed(() => {
  const orig = tokenize(props.original);
  const corr = new Set(
    tokenize(props.corrected)
      .map(t => t.trim())
      .filter(Boolean)
  );
  return orig.map(tok => ({
    text: tok,
    changed: tok.trim() && !corr.has(tok.trim()),
  }));
});

const correctedTokens = computed(() => {
  const corr = tokenize(props.corrected);
  const orig = new Set(
    tokenize(props.original)
      .map(t => t.trim())
      .filter(Boolean)
  );
  return corr.map(tok => ({
    text: tok,
    changed: tok.trim() && !orig.has(tok.trim()),
  }));
});
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    width="2xl"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="close"
  >
    <div class="flex flex-col gap-3 text-sm">
      <div class="flex items-center gap-2">
        <span class="i-lucide-spell-check size-5 text-n-amber-9" />
        <h3 class="text-base font-semibold text-n-slate-12">
          {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.TITLE') }}
        </h3>
      </div>
      <p class="text-n-slate-11">
        {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.INTRO') }}
      </p>

      <div class="rounded-lg border border-n-ruby-6 bg-n-ruby-2 p-3">
        <div
          class="mb-1 text-[11px] font-bold uppercase tracking-wide text-n-ruby-11"
        >
          {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.ORIGINAL_LABEL') }}
        </div>
        <div class="whitespace-pre-wrap leading-relaxed text-n-slate-12">
          <span
            v-for="(tok, i) in originalTokens"
            :key="`o-${i}`"
            :class="
              tok.changed
                ? 'rounded bg-n-ruby-3 px-0.5 font-semibold text-n-ruby-12 line-through decoration-n-ruby-9 decoration-2'
                : ''
            "
          >
            {{ tok.text }}
          </span>
        </div>
      </div>

      <div class="rounded-lg border border-n-teal-6 bg-n-teal-2 p-3">
        <div
          class="mb-1 text-[11px] font-bold uppercase tracking-wide text-n-teal-11"
        >
          {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.CORRECTED_LABEL') }}
        </div>
        <div class="whitespace-pre-wrap leading-relaxed text-n-slate-12">
          <span
            v-for="(tok, i) in correctedTokens"
            :key="`c-${i}`"
            :class="
              tok.changed
                ? 'rounded bg-n-teal-3 px-0.5 font-semibold text-n-teal-12'
                : ''
            "
          >
            {{ tok.text }}
          </span>
        </div>
      </div>

      <div
        v-if="confirmOriginal"
        class="rounded-md border border-n-amber-6 bg-n-amber-2 px-3 py-2 text-[12px] text-n-amber-12"
      >
        {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.CONFIRM_HINT') }}
      </div>

      <div class="flex items-center justify-between gap-2 pt-2">
        <Button slate sm faded type="button" @click="onEdit">
          {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.EDIT') }}
        </Button>
        <div class="flex items-center gap-2">
          <Button
            :ruby="confirmOriginal"
            :slate="!confirmOriginal"
            sm
            faded
            type="button"
            @click="onSendOriginalClick"
          >
            {{
              confirmOriginal
                ? $t('CONVERSATION.REPLYBOX.SPELL_CHECK.CONFIRM_SEND_ORIGINAL')
                : $t('CONVERSATION.REPLYBOX.SPELL_CHECK.SEND_ORIGINAL')
            }}
          </Button>
          <Button solid sm type="button" @click="onSendCorrected">
            {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.SEND_CORRECTED') }}
          </Button>
        </div>
      </div>
    </div>
  </Dialog>
</template>
