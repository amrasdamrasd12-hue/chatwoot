<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

// Eltafouk: pre-send spell/grammar guard, designed as a calm editor's
// proof — corrected version reads as the polished final draft, original
// sits below with marker-pen circles + tiny numbered margin-marks on each
// changed word. Hovering a circled word reveals the plain-Arabic
// reasoning from the model. Backend now authoritatively lists what's
// "really" wrong via the `fixes` array, so the modal trusts that list
// (no more whitespace/punctuation false positives from naive diffing).
const props = defineProps({
  show: { type: Boolean, default: false },
  original: { type: String, default: '' },
  corrected: { type: String, default: '' },
  fixes: { type: Array, default: () => [] },
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

// Strip Arabic + Latin punctuation so word matching works even when a
// token carries a comma or question mark stuck to it ("اهلن،" matches
// fix.wrong "اهلن"). Without this, the model's fix list would miss most
// real-world tokens because they're glued to punctuation.
const ARABIC_PUNCT_RE = /[،؛؟.,!?"'"'":()[\]{}«»…]+/g;
const cleanWord = s => (s || '').replace(ARABIC_PUNCT_RE, '').trim();

// Keep whitespace tokens as separators so we can reconstruct original
// spacing exactly when we render.
const tokenize = text => (text || '').split(/(\s+)/);

// Annotate each fix with a 1-based index — that index becomes the tiny
// superscript number on both sides, letting the agent pair "اهلن¹" in
// the original with "أهلاً¹" in the corrected at a glance.
const fixesWithIndex = computed(() =>
  props.fixes
    .map((fix, idx) => ({ ...fix, idx: idx + 1 }))
    .filter(f => f.wrong && f.right)
);

const wrongWordsMap = computed(() => {
  const map = new Map();
  fixesWithIndex.value.forEach(fix => {
    const key = cleanWord(fix.wrong);
    if (key) map.set(key, fix);
  });
  return map;
});

const rightWordsMap = computed(() => {
  const map = new Map();
  fixesWithIndex.value.forEach(fix => {
    const key = cleanWord(fix.right);
    if (key) map.set(key, fix);
  });
  return map;
});

// Defensive diff: small models occasionally skip a fix entry even when
// they correct the word in `corrected`. Without backup detection the
// real misspelling would render unhighlighted because nothing in
// `wrongWordsMap` anchors on it. To avoid silent diffs we union the
// model's explicit fixes with a word-set diff against the opposite
// side — any word that exists on one side but is missing from the
// other side is implicitly "changed" and gets a generic tooltip.
const correctedCleanSet = computed(() => {
  const s = new Set();
  tokenize(props.corrected).forEach(t => {
    const k = cleanWord(t);
    if (k) s.add(k);
  });
  return s;
});

const originalCleanSet = computed(() => {
  const s = new Set();
  tokenize(props.original).forEach(t => {
    const k = cleanWord(t);
    if (k) s.add(k);
  });
  return s;
});

const FALLBACK_FIX = { wrong: '', right: '', why: 'خطأ إملائي', idx: 0 };

const originalTokens = computed(() =>
  tokenize(props.original).map(tok => {
    const key = cleanWord(tok);
    if (!key) return { text: tok, fix: null };
    const explicit = wrongWordsMap.value.get(key);
    if (explicit) return { text: tok, fix: explicit };
    // Implicit change: word lives in original but doesn't survive into
    // corrected — the model fixed it but forgot to list it.
    if (!correctedCleanSet.value.has(key)) {
      return { text: tok, fix: FALLBACK_FIX };
    }
    return { text: tok, fix: null };
  })
);

const correctedTokens = computed(() =>
  tokenize(props.corrected).map(tok => {
    const key = cleanWord(tok);
    if (!key) return { text: tok, fix: null };
    const explicit = rightWordsMap.value.get(key);
    if (explicit) return { text: tok, fix: explicit };
    // Same idea on the corrected side: a word that appeared from
    // nowhere is a fix the model didn't enumerate. Show it teal so
    // the agent still sees what changed.
    if (!originalCleanSet.value.has(key)) {
      return { text: tok, fix: FALLBACK_FIX };
    }
    return { text: tok, fix: null };
  })
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
    width="2xl"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="close"
  >
    <div class="flex flex-col gap-4">
      <!-- Header: chip icon + title. Slightly larger now to anchor the
           taller modal. -->
      <header class="flex items-center gap-3">
        <span
          class="grid size-9 place-items-center rounded-xl bg-n-amber-3 ring-1 ring-n-amber-7 shadow-sm"
          aria-hidden="true"
        >
          <span class="i-lucide-spell-check size-[18px] text-n-amber-11" />
        </span>
        <h3 class="text-[17px] font-semibold tracking-tight text-n-slate-12">
          {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.TITLE') }}
        </h3>
      </header>

      <!-- HERO: corrected message. Reads like the polished final draft —
           larger type, generous line-height, teal accent stripe on the
           right (RTL leading edge). Highlighted words get a confident
           teal pill + numbered superscript that pairs them with the
           same number in the original below. -->
      <div
        class="relative overflow-hidden rounded-2xl bg-n-teal-2 px-5 pb-5 pt-4 shadow-sm ring-1 ring-n-teal-6"
      >
        <span
          class="absolute inset-y-0 right-0 w-1 bg-n-teal-9"
          aria-hidden="true"
        />
        <div class="mb-2.5 flex items-center gap-1.5">
          <span
            class="i-lucide-sparkles size-3.5 text-n-teal-11"
            aria-hidden="true"
          />
          <span
            class="text-[10.5px] font-bold uppercase tracking-[0.16em] text-n-teal-11"
          >
            {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.CORRECTED_LABEL') }}
          </span>
        </div>
        <p
          class="whitespace-pre-wrap text-[19px] font-medium leading-[1.85] text-n-slate-12"
        >
          <span v-for="(tok, i) in correctedTokens" :key="`c-${i}`">
            <span
              v-if="tok.fix"
              :title="tok.fix.why"
              class="group/fix relative inline-block cursor-help rounded-md bg-n-teal-4 px-1.5 py-px font-bold text-n-teal-12 ring-1 ring-inset ring-n-teal-7/50 transition-colors hover:bg-n-teal-5"
            >
              {{ tok.text }}
              <span
                class="pointer-events-none absolute bottom-full start-1/2 z-50 mb-1.5 -translate-x-1/2 whitespace-nowrap rounded-lg bg-n-slate-12 px-2.5 py-1.5 text-[12px] font-medium text-white opacity-0 shadow-lg transition-opacity duration-150 group-hover/fix:opacity-100 rtl:translate-x-1/2"
              >
                {{ tok.fix.why }}
                <span
                  class="absolute top-full start-1/2 -translate-x-1/2 border-[5px] border-x-transparent border-b-transparent border-t-n-slate-12 rtl:translate-x-1/2"
                  aria-hidden="true"
                />
              </span>
            </span>
            <template v-else>
              {{ tok.text }}
            </template>
          </span>
        </p>
      </div>

      <!-- Original: reference, smaller and quieter than the hero so the
           eye lands on the corrected version first. Wrong words get a
           red marker-pen circle (soft red bg + thicker red underline,
           NOT strikethrough) and the matching numbered superscript. -->
      <div class="rounded-xl bg-n-alpha-1 px-5 py-4 ring-1 ring-n-slate-4">
        <div class="mb-2 flex items-center gap-1.5">
          <span
            class="i-lucide-pencil-line size-3.5 text-n-ruby-10"
            aria-hidden="true"
          />
          <span
            class="text-[10.5px] font-bold uppercase tracking-[0.16em] text-n-ruby-11"
          >
            {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.ORIGINAL_LABEL') }}
          </span>
        </div>
        <p
          class="whitespace-pre-wrap text-[16px] leading-[1.75] text-n-slate-11"
        >
          <span v-for="(tok, i) in originalTokens" :key="`o-${i}`">
            <span
              v-if="tok.fix"
              :title="tok.fix.why"
              class="group/fix relative inline-block cursor-help rounded-md bg-n-ruby-3 px-1.5 py-px font-bold text-n-ruby-12 ring-1 ring-inset ring-n-ruby-7/50 transition-colors hover:bg-n-ruby-4"
            >
              {{ tok.text }}
              <span
                class="pointer-events-none absolute bottom-full start-1/2 z-50 mb-1.5 -translate-x-1/2 whitespace-nowrap rounded-lg bg-n-slate-12 px-2.5 py-1.5 text-[12px] font-medium text-white opacity-0 shadow-lg transition-opacity duration-150 group-hover/fix:opacity-100 rtl:translate-x-1/2"
              >
                {{ tok.fix.why }}
                <span
                  class="absolute top-full start-1/2 -translate-x-1/2 border-[5px] border-x-transparent border-b-transparent border-t-n-slate-12 rtl:translate-x-1/2"
                  aria-hidden="true"
                />
              </span>
            </span>
            <template v-else>
              {{ tok.text }}
            </template>
          </span>
        </p>
        <!-- Discovery hint: surfaces the hover behavior for first-time
             users without nagging veterans on every send. -->
        <p
          class="mt-3 flex items-center gap-1.5 text-[12px] italic text-n-slate-10"
        >
          <span
            class="i-lucide-info size-3 text-n-slate-9"
            aria-hidden="true"
          />
          {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.HOVER_HINT') }}
        </p>
      </div>

      <!-- Confirm warning: only when the user is about to bypass the
           correction. Smooth slide-in keeps layout from jumping. -->
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
          <span class="text-[12.5px] leading-snug text-n-amber-12">
            {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.CONFIRM_HINT') }}
          </span>
        </div>
      </Transition>

      <!-- Action row. Substantial 40px-tall buttons so the primary feels
           like a real "ship it" decision, not a throwaway. Primary
           anchored RTL-end with the standard ⏎ kbd hint; tertiary
           (edit) anchored RTL-start. -->
      <footer class="flex items-center justify-between gap-3 pt-1">
        <button
          type="button"
          class="group inline-flex h-10 items-center gap-2 rounded-lg px-3 text-[13px] font-medium text-n-slate-11 transition-colors hover:bg-n-alpha-2 hover:text-n-slate-12"
          @click="onEdit"
        >
          {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.EDIT') }}
          <kbd
            class="rounded bg-n-alpha-2 px-1.5 py-0.5 font-mono text-[10.5px] font-normal text-n-slate-10 group-hover:bg-n-alpha-3"
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
            class="h-10 rounded-lg px-4 text-[13px] font-medium ring-1 transition-colors"
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
            class="inline-flex h-10 items-center gap-2 rounded-lg bg-n-brand px-4 text-[13.5px] font-semibold text-white shadow-md shadow-n-brand/25 transition-all hover:brightness-110 hover:shadow-lg hover:shadow-n-brand/35 active:scale-[0.98]"
            @click="onSendCorrected"
          >
            <span class="i-lucide-check size-4" aria-hidden="true" />
            <span>
              {{ $t('CONVERSATION.REPLYBOX.SPELL_CHECK.SEND_CORRECTED') }}
            </span>
            <kbd
              class="rounded bg-white/15 px-1.5 py-0.5 font-mono text-[10.5px] font-normal ring-1 ring-white/20"
            >
              {{ KEY_ENTER }}
            </kbd>
          </button>
        </div>
      </footer>
    </div>
  </Dialog>
</template>
