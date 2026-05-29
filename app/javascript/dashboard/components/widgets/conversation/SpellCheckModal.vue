<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

// Eltafouk: pre-send spell/grammar guard. Hierarchy: the AI-corrected line
// is the hero (large, teal-accented manuscript-proof block); the original
// sits under it as muted reference with strikethrough on changed tokens.
// Goal is single-glance comprehension — agents see this on every flawed
// send so it must dismiss in under a second of cognitive load.
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

// Universal keyboard glyphs — bound through script setup so the linter
// treats them as data, not bare i18n strings (they have no translation).
const KEY_ENTER = '↩';
const KEY_ESC = 'Esc';

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

const changeCount = computed(
  () => correctedTokens.value.filter(t => t.changed).length
);

// Keyboard shortcuts turn the modal into a one-keypress flow for power
// users: Enter accepts the correction (the by-far most common action),
// Esc is handled by the native <dialog> element and falls back to the
// editor with the draft preserved. We intentionally do NOT bind a
// shortcut for "send original" — that path requires deliberate clicks
// so a single mistaken keystroke can't bypass the spell-check.
const handleKeydown = e => {
  if (!props.show) return;
  const isPlainEnter =
    e.key === 'Enter' && !e.shiftKey && !e.metaKey && !e.ctrlKey && !e.altKey;
  if (isPlainEnter) {
    e.preventDefault();
    onSendCorrected();
  }
};

onMounted(() => window.addEventListener('keydown', handleKeydown));
onBeforeUnmount(() => window.removeEventListener('keydown', handleKeydown));
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    width="xl"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="close"
  >
    <div class="flex flex-col gap-3">
      <!-- Header strip: icon chip + title + change count. Keeps vertical
           real-estate cheap so the diff dominates. -->
      <header class="flex items-center justify-between gap-3">
        <div class="flex items-center gap-2.5">
          <span
            class="grid size-7 place-items-center rounded-lg bg-n-amber-3 ring-1 ring-n-amber-6"
            aria-hidden="true"
          >
            <span class="i-lucide-spell-check size-4 text-n-amber-11" />
          </span>
          <h3
            class="text-[14.5px] font-semibold tracking-tight text-n-slate-12"
          >
            {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.TITLE') }}
          </h3>
        </div>
        <span
          v-if="changeCount > 0"
          class="rounded-full bg-n-amber-2 px-2 py-0.5 text-[10.5px] font-bold tabular-nums text-n-amber-11 ring-1 ring-n-amber-6"
        >
          {{ changeCount }}
        </span>
      </header>

      <!-- HERO: corrected message. The right-edge teal stripe acts as an
           editor's flag (in RTL the right edge is the "leading" side). -->
      <div
        class="relative overflow-hidden rounded-xl bg-n-teal-2 px-4 pb-3.5 pt-3 ring-1 ring-n-teal-6"
      >
        <span
          class="absolute inset-y-0 right-0 w-[3px] bg-n-teal-9"
          aria-hidden="true"
        />
        <div class="mb-1.5 flex items-center gap-1.5">
          <span
            class="i-lucide-sparkles size-3 text-n-teal-11"
            aria-hidden="true"
          />
          <span
            class="text-[10.5px] font-bold uppercase tracking-[0.14em] text-n-teal-11"
          >
            {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.CORRECTED_LABEL') }}
          </span>
        </div>
        <p
          class="whitespace-pre-wrap text-[16.5px] font-medium leading-[1.75] text-n-slate-12"
        >
          <span
            v-for="(tok, i) in correctedTokens"
            :key="`c-${i}`"
            :class="
              tok.changed
                ? 'rounded-md bg-n-teal-4 px-1 py-px font-bold text-n-teal-12 ring-1 ring-inset ring-n-teal-7/40'
                : ''
            "
          >
            {{ tok.text }}
          </span>
        </p>
      </div>

      <!-- Original (reference). Lower weight + size + opacity = the eye
           reads it second, only when curious about "what was wrong". -->
      <div class="rounded-lg bg-n-alpha-1 px-4 py-2.5 ring-1 ring-n-slate-4">
        <div class="mb-1 flex items-center gap-1.5">
          <span
            class="i-lucide-pencil-line size-3 text-n-ruby-10"
            aria-hidden="true"
          />
          <span
            class="text-[10px] font-bold uppercase tracking-[0.14em] text-n-ruby-11"
          >
            {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.ORIGINAL_LABEL') }}
          </span>
        </div>
        <p
          class="whitespace-pre-wrap text-[13.5px] leading-[1.65] text-n-slate-10"
        >
          <span
            v-for="(tok, i) in originalTokens"
            :key="`o-${i}`"
            :class="
              tok.changed
                ? 'text-n-ruby-11 line-through decoration-n-ruby-9 decoration-[1.5px] underline-offset-2'
                : ''
            "
          >
            {{ tok.text }}
          </span>
        </p>
      </div>

      <!-- Inline confirm slip. Slide-in keeps layout from jumping. -->
      <Transition
        enter-active-class="transition-all duration-200 ease-out"
        enter-from-class="-translate-y-1 opacity-0"
        enter-to-class="translate-y-0 opacity-100"
      >
        <div
          v-if="confirmOriginal"
          class="flex items-start gap-2 rounded-md bg-n-amber-2 px-3 py-2 ring-1 ring-n-amber-6"
        >
          <span
            class="i-lucide-triangle-alert mt-px size-3.5 shrink-0 text-n-amber-10"
            aria-hidden="true"
          />
          <span class="text-[12px] leading-snug text-n-amber-12">
            {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.CONFIRM_HINT') }}
          </span>
        </div>
      </Transition>

      <!-- Action row. Primary anchored to RTL "end" (right side), tertiary
           (edit) anchored to RTL "start". Inline kbd hints encourage the
           one-keypress flow without cluttering the buttons. -->
      <footer class="flex items-center justify-between gap-3 pt-1">
        <button
          type="button"
          class="group inline-flex items-center gap-1.5 rounded-md px-2 py-1.5 text-[12.5px] font-medium text-n-slate-11 transition-colors hover:bg-n-alpha-2 hover:text-n-slate-12"
          @click="onEdit"
        >
          {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.EDIT') }}
          <kbd
            class="rounded bg-n-alpha-2 px-1 py-px font-mono text-[10px] font-normal text-n-slate-10 group-hover:bg-n-alpha-3"
          >
            {{ KEY_ESC }}
          </kbd>
        </button>

        <div class="flex items-center gap-2">
          <button
            type="button"
            :class="
              confirmOriginal
                ? 'bg-n-ruby-3 text-n-ruby-12 ring-n-ruby-7 hover:bg-n-ruby-4'
                : 'bg-n-alpha-2 text-n-slate-12 ring-n-alpha-2 hover:bg-n-alpha-3'
            "
            class="rounded-md px-3 py-1.5 text-[12.5px] font-medium ring-1 transition-colors"
            @click="onSendOriginalClick"
          >
            {{
              confirmOriginal
                ? $t('CONVERSATION.REPLYBOX.SPELL_CHECK.CONFIRM_SEND_ORIGINAL')
                : $t('CONVERSATION.REPLYBOX.SPELL_CHECK.SEND_ORIGINAL')
            }}
          </button>
          <button
            type="button"
            class="inline-flex items-center gap-1.5 rounded-md bg-n-brand px-3.5 py-1.5 text-[13px] font-semibold text-white shadow-sm transition-all hover:brightness-110 active:scale-[0.98]"
            @click="onSendCorrected"
          >
            <span class="i-lucide-check size-3.5" aria-hidden="true" />
            <span>{{
              $t('CONVERSATION.REPLYBOX.SPELL_CHECK.SEND_CORRECTED')
            }}</span>
            <kbd
              class="rounded bg-white/15 px-1 py-px font-mono text-[10px] font-normal ring-1 ring-white/20"
            >
              {{ KEY_ENTER }}
            </kbd>
          </button>
        </div>
      </footer>
    </div>
  </Dialog>
</template>
