<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import SpellCheckReportsAPI from 'dashboard/api/spellCheckReports';

const store = useStore();

// Eltafouk-only Arabic-first page — bind all visible copy through this
// constant object so the @intlify lint rule treats them as script data
// rather than bare i18n strings. Keys are scoped to this file; no need
// to round-trip through en.json for a UI that ships in Arabic only.
const L = {
  TITLE: 'تقرير المدقق الإملائي',
  SUBTITLE:
    'مرجعية تقييم الموظفين إملائياً: معدّل الأخطاء، أنواعها، وأكتر الكلمات اللي بيغلطوا فيها.',
  FROM: 'من',
  TO: 'إلى',
  APPLY: 'تطبيق',
  EXPORT: 'تصدير CSV',
  LOADING: 'جاري التحميل…',
  EMPTY: 'مفيش بيانات في النطاق المختار.',
  TOTAL_CHECKS: 'إجمالي الفحوصات',
  TOTAL_FIXES: 'إجمالي الأخطاء',
  CORRECTED: 'تصحيحات مقبولة',
  SENT_ORIGINAL: 'أُرسل النص الأصلي',
  EDITED: 'رجع للتعديل',
  COMPARE: 'مقارنة الموظفين',
  COMPARE_HINT: 'اضغط على أي موظف لعرض أنواع أخطائه وأكتر الكلمات تكراراً.',
  COL_AGENT: 'الموظف',
  COL_TOTAL: 'فحوصات',
  COL_ERR_RATE: 'معدّل الخطأ',
  COL_ERRORS: 'أخطاء',
  COL_BEHAVIOR: 'سلوكه',
  COL_RATE: 'قبول التصحيح',
  CATEGORIES_TITLE: 'تصنيف الأخطاء (الكل)',
  CATEGORIES_HINT: 'توزيع كل الأخطاء المكتشفة على الأنواع في النطاق المختار.',
  AGENT_CATEGORIES: 'أنواع أخطاء الموظف',
  AGENT_TOP: 'أكتر الكلمات غلطاً',
  TOP_TITLE: 'أكتر الأخطاء تكراراً (كل الموظفين)',
  TOP_HINT: 'نقاط الضعف المشتركة اللي تستاهل تنبيه للفريق كله.',
  TREND_TITLE: 'النشاط اليومي',
  FAIR_TITLE: 'انتبه للعدل في المقارنة',
  FAIR_LEVELS: 'البيانات دي بتشمل مستويات تدقيق مختلفة',
  FAIR_HINT:
    'الموظف على مستوى أعلى بتظهر عليه أخطاء أكتر تلقائياً. للمقارنة العادلة وحّد المستوى من إعدادات المدقق.',
  MODELS: 'الموديلات',
  NO_MISTAKES: 'مفيش أخطاء متسجّلة لهذا الموظف.',
  LEGEND_CORRECTED: 'قبل التصحيح',
  LEGEND_SENT: 'أرسل الأصلي',
  LEGEND_EDITED: 'رجع للتعديل',
  TIMES: 'مرة',
  TZ_NOTE: 'بتوقيت القاهرة',
  CORR_TITLE: 'جدول التصحيحات الكامل',
  CORR_WRONG: 'الخطأ',
  CORR_RIGHT: 'التصحيح',
  CORR_DECISION: 'القرار',
  CORR_CATEGORY: 'النوع',
  CORR_DATE: 'التاريخ',
  CORR_CONV: 'المحادثة',
  CORR_LOADING: 'جاري تحميل التصحيحات…',
  CORR_ACCEPTED: 'قبل',
  CORR_REJECTED: 'رفض',
  CORR_EDITED: 'عدّل',
  CORR_NOERR: 'بدون خطأ',
};

// Stable category keys ←→ Arabic label + chip colours. Full literal
// class strings so Tailwind's JIT scanner picks them up.
const CATEGORY_META = {
  hamza: {
    label: 'همزة',
    chip: 'bg-n-iris-3 text-n-iris-11',
    dot: 'bg-n-iris-9',
  },
  tanween: {
    label: 'تنوين',
    chip: 'bg-n-amber-3 text-n-amber-11',
    dot: 'bg-n-amber-9',
  },
  taa: {
    label: 'تاء/هاء',
    chip: 'bg-n-teal-3 text-n-teal-11',
    dot: 'bg-n-teal-9',
  },
  ya: {
    label: 'ياء/ألف مقصورة',
    chip: 'bg-n-blue-3 text-n-blue-11',
    dot: 'bg-n-blue-9',
  },
  letter_missing: {
    label: 'حرف ناقص',
    chip: 'bg-n-ruby-3 text-n-ruby-11',
    dot: 'bg-n-ruby-9',
  },
  letter_extra: {
    label: 'حرف زائد',
    chip: 'bg-n-ruby-3 text-n-ruby-11',
    dot: 'bg-n-ruby-9',
  },
  letter_wrong: {
    label: 'حرف غلط',
    chip: 'bg-n-ruby-3 text-n-ruby-11',
    dot: 'bg-n-ruby-9',
  },
  diacritic: {
    label: 'تشكيل',
    chip: 'bg-n-slate-3 text-n-slate-11',
    dot: 'bg-n-slate-9',
  },
  punctuation: {
    label: 'ترقيم/تطويل',
    chip: 'bg-n-slate-3 text-n-slate-11',
    dot: 'bg-n-slate-9',
  },
  other: {
    label: 'أخرى',
    chip: 'bg-n-slate-3 text-n-slate-11',
    dot: 'bg-n-slate-9',
  },
};
const categoryLabel = c => CATEGORY_META[c]?.label || c;
const categoryChip = c => CATEGORY_META[c]?.chip || CATEGORY_META.other.chip;
const categoryDot = c => CATEGORY_META[c]?.dot || CATEGORY_META.other.dot;

const PRESETS = [
  { key: 'today', days: 0, label: 'اليوم' },
  { key: 'yesterday', days: 1, label: 'أمس' },
  { key: 'week', days: 7, label: 'آخر 7 أيام' },
  { key: 'month', days: 30, label: 'آخر 30 يوم' },
  { key: 'quarter', days: 90, label: 'آخر 3 شهور' },
];

const activePreset = ref('week');
const customFrom = ref('');
const customTo = ref('');
const isCustom = ref(false);

const report = ref(null);
const loading = ref(false);
const error = ref(null);
const expanded = ref(new Set());
const agentCorrections = ref({});
const correctionsLoading = ref({});

const allAgents = computed(() => store.getters['agents/getAgents'] || []);

const isoDate = d => {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

const rangeIso = computed(() => {
  const now = new Date();
  if (isCustom.value) {
    return {
      since: customFrom.value || isoDate(new Date(now - 30 * 86400000)),
      until: customTo.value || isoDate(now),
    };
  }
  const preset = PRESETS.find(p => p.key === activePreset.value);
  if (preset?.key === 'today') {
    return { since: isoDate(now), until: isoDate(now) };
  }
  if (preset?.key === 'yesterday') {
    const y = new Date(now - 86400000);
    return { since: isoDate(y), until: isoDate(y) };
  }
  return {
    since: isoDate(new Date(now - preset.days * 86400000)),
    until: isoDate(now),
  };
});

const rangeLabel = computed(() => {
  const r = rangeIso.value;
  return r.since === r.until ? r.since : `${r.since} — ${r.until}`;
});

const fetchReport = async () => {
  loading.value = true;
  error.value = null;
  expanded.value = new Set();
  agentCorrections.value = {};
  correctionsLoading.value = {};
  try {
    const { data } = await SpellCheckReportsAPI.fetch(rangeIso.value);
    report.value = data;
  } catch (e) {
    error.value = e.message || 'فشل التحميل';
  } finally {
    loading.value = false;
  }
};

onMounted(async () => {
  if (!allAgents.value.length) {
    await store.dispatch('agents/get');
  }
  await fetchReport();
});

watch(activePreset, () => {
  if (!isCustom.value) fetchReport();
});

const summary = computed(() => report.value?.summary || null);
const byAgent = computed(() => report.value?.by_agent || []);
const topMistakes = computed(() => report.value?.top_mistakes || []);
const segments = computed(() => report.value?.meta?.segments || null);
const byDay = computed(() => report.value?.by_day || []);

// Global category breakdown, biggest first, zeros dropped.
const globalCategories = computed(() => {
  const obj = summary.value?.by_category || {};
  return Object.entries(obj)
    .filter(([, n]) => n > 0)
    .sort((a, b) => b[1] - a[1]);
});
const totalFixes = computed(() => summary.value?.total_fixes || 0);

// Fairness: how many distinct strictness levels the data spans. More
// than one → cross-agent comparison is on different rulers.
const strictnessLevels = computed(() =>
  Object.keys(segments.value?.by_strictness || {}).sort()
);
const modelsUsed = computed(() =>
  Object.keys(segments.value?.by_model || {}).filter(m => m && m !== 'unknown')
);
const mixedLevels = computed(() => strictnessLevels.value.length > 1);

const correctedRate = a =>
  a.total ? Math.round((100 * (a.decisions.corrected || 0)) / a.total) : 0;
const sentOriginalRate = a =>
  a.total ? Math.round((100 * (a.decisions.sent_original || 0)) / a.total) : 0;
const editedRate = a =>
  a.total ? Math.round((100 * (a.decisions.edited || 0)) / a.total) : 0;
// Share of this agent's checks where the model found at least one error.
const errorRate = a =>
  a.total
    ? Math.round(
        (100 * (a.total - (a.decisions.no_errors_send || 0))) / a.total
      )
    : 0;

const agentCategories = a =>
  Object.entries(a.categories || {})
    .filter(([, n]) => n > 0)
    .sort((x, y) => y[1] - x[1]);

const maxAgentTotal = computed(() =>
  byAgent.value.reduce((m, a) => Math.max(m, a.total), 1)
);

function dayTotal(d) {
  return Object.entries(d).reduce(
    (s, [k, v]) => (k === 'date' ? s : s + (Number(v) || 0)),
    0
  );
}
const maxDayTotal = computed(() =>
  byDay.value.reduce((m, d) => Math.max(m, dayTotal(d)), 1)
);
const dayLabel = iso => (iso || '').slice(5); // MM-DD

const pickPreset = key => {
  activePreset.value = key;
  isCustom.value = false;
};
const applyCustom = () => {
  isCustom.value = true;
  fetchReport();
};

const agentKey = a => a.user_id || 'na';
const isExpanded = a => expanded.value.has(agentKey(a));
const toggleAgent = async a => {
  const key = agentKey(a);
  const next = new Set(expanded.value);
  if (next.has(key)) {
    next.delete(key);
  } else {
    next.add(key);
    // Lazy-fetch corrections if not loaded yet
    if (!agentCorrections.value[key] && a.user_id) {
      correctionsLoading.value = { ...correctionsLoading.value, [key]: true };
      try {
        const { data } = await SpellCheckReportsAPI.fetchCorrections({
          ...rangeIso.value,
          userId: a.user_id,
        });
        agentCorrections.value = {
          ...agentCorrections.value,
          [key]: data.corrections || [],
        };
      } catch (e) {
        agentCorrections.value = { ...agentCorrections.value, [key]: [] };
      } finally {
        correctionsLoading.value = {
          ...correctionsLoading.value,
          [key]: false,
        };
      }
    }
  }
  expanded.value = next;
};

const DECISION_META = {
  corrected: {
    label: L.CORR_ACCEPTED,
    icon: 'i-lucide-check',
    cls: 'text-n-teal-11',
  },
  sent_original: {
    label: L.CORR_REJECTED,
    icon: 'i-lucide-x',
    cls: 'text-n-ruby-11',
  },
  edited: {
    label: L.CORR_EDITED,
    icon: 'i-lucide-pencil',
    cls: 'text-n-amber-11',
  },
  pending: {
    label: 'تجاهل',
    icon: 'i-lucide-skip-forward',
    cls: 'text-n-slate-11',
  },
  no_errors_send: {
    label: L.CORR_NOERR,
    icon: 'i-lucide-minus',
    cls: 'text-n-slate-10',
  },
};
const decisionMeta = d => DECISION_META[d] || DECISION_META.pending;

const fmtDate = iso => {
  if (!iso) return '';
  const d = new Date(iso);
  const pad = n => String(n).padStart(2, '0');
  let hours = d.getHours();
  const ampm = hours >= 12 ? 'PM' : 'AM';
  hours %= 12;
  hours = hours || 12;
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(hours)}:${pad(d.getMinutes())} ${ampm}`;
};

const convUrl = (convId, messageId) => {
  if (!convId) return null;
  const accountId = store.getters.getCurrentAccountId;
  let url = `/app/accounts/${accountId}/conversations/${convId}`;
  if (messageId) {
    url += `?messageId=${messageId}`;
  }
  return url;
};

const csvCell = v => {
  const s = String(v ?? '');
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};
const exportCsv = () => {
  const header = [
    L.COL_AGENT,
    'البريد',
    L.TOTAL_CHECKS,
    L.COL_ERRORS,
    'معدل الخطأ %',
    'قبول التصحيح %',
    'أرسل الأصلي %',
    'رجع للتعديل %',
  ];
  const lines = byAgent.value.map(a => [
    a.name,
    a.email || '',
    a.total,
    a.errors_caught,
    errorRate(a),
    correctedRate(a),
    sentOriginalRate(a),
    editedRate(a),
  ]);
  const csv = [header, ...lines].map(r => r.map(csvCell).join(',')).join('\n');
  // Lead with a UTF-8 BOM so Excel opens Arabic columns correctly.
  const blob = new Blob(['\uFEFF', csv], {
    type: 'text/csv;charset=utf-8',
  });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `spell-check-report-${rangeIso.value.since}_${rangeIso.value.until}.csv`;
  link.click();
  URL.revokeObjectURL(url);
};
</script>

<template>
  <div class="flex flex-col gap-6 p-6">
    <!-- Header -->
    <header class="flex flex-wrap items-start justify-between gap-4">
      <div class="flex items-center gap-3">
        <span
          class="grid size-10 place-items-center rounded-xl bg-n-brand/15 text-n-brand"
        >
          <span class="i-lucide-spell-check size-5" />
        </span>
        <div>
          <h1 class="text-[18px] font-semibold tracking-tight text-n-slate-12">
            {{ L.TITLE }}
          </h1>
          <p class="mt-0.5 text-[12.5px] text-n-slate-11 flex-wrap">
            {{ L.SUBTITLE }}
          </p>
        </div>
      </div>
      <button
        v-if="byAgent.length"
        type="button"
        class="inline-flex shrink-0 items-center gap-2 rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-[12.5px] font-medium text-n-slate-12 shadow-sm transition-colors hover:bg-n-alpha-2"
        @click="exportCsv"
      >
        <span
          class="i-lucide-download size-4 text-n-slate-11"
          aria-hidden="true"
        />
        {{ L.EXPORT }}
      </button>
    </header>

    <!-- Filter bar -->
    <div
      class="flex flex-wrap items-center gap-x-4 gap-y-3 rounded-2xl border border-n-weak bg-n-solid-1 p-2.5 shadow-sm"
    >
      <!-- preset pills -->
      <div class="flex items-center gap-1 rounded-xl bg-n-alpha-1 p-1">
        <button
          v-for="p in PRESETS"
          :key="p.key"
          type="button"
          class="rounded-lg px-3 py-1.5 text-[12.5px] font-medium transition-all"
          :class="
            !isCustom && activePreset === p.key
              ? 'bg-n-brand text-white shadow-sm'
              : 'text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
          "
          @click="pickPreset(p.key)"
        >
          {{ p.label }}
        </button>
      </div>

      <div class="h-6 w-px bg-n-weak" />

      <!-- custom range -->
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-[12px] text-n-slate-10">{{ L.FROM }}</span>
        <label
          class="inline-flex items-center gap-1.5 rounded-lg border px-2.5 py-1.5 transition-colors focus-within:border-n-brand"
          :class="
            isCustom
              ? 'border-n-slate-5 bg-n-solid-1'
              : 'border-n-weak bg-n-alpha-1'
          "
        >
          <span class="i-lucide-calendar size-3.5 text-n-slate-10" />
          <input
            v-model="customFrom"
            type="date"
            dir="ltr"
            class="w-[112px] bg-transparent text-[12.5px] tabular-nums text-n-slate-12 outline-none"
          />
        </label>
        <span class="text-[12px] text-n-slate-10">{{ L.TO }}</span>
        <label
          class="inline-flex items-center gap-1.5 rounded-lg border px-2.5 py-1.5 transition-colors focus-within:border-n-brand"
          :class="
            isCustom
              ? 'border-n-slate-5 bg-n-solid-1'
              : 'border-n-weak bg-n-alpha-1'
          "
        >
          <span class="i-lucide-calendar size-3.5 text-n-slate-10" />
          <input
            v-model="customTo"
            type="date"
            dir="ltr"
            class="w-[112px] bg-transparent text-[12.5px] tabular-nums text-n-slate-12 outline-none"
          />
        </label>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 rounded-lg bg-n-brand px-3 py-1.5 text-[12.5px] font-medium text-white shadow-sm transition-opacity hover:opacity-90"
          @click="applyCustom"
        >
          <span class="i-lucide-check size-3.5" />
          {{ L.APPLY }}
        </button>
      </div>

      <!-- active range chip -->
      <div
        class="ms-auto inline-flex items-center gap-1.5 rounded-lg bg-n-alpha-1 px-2.5 py-1.5 text-[12px] tabular-nums text-n-slate-11"
      >
        <span class="i-lucide-clock-3 size-3.5 text-n-slate-10" />
        <span dir="ltr">{{ rangeLabel }}</span>
        <span class="size-1 rounded-full bg-n-slate-8" />
        <span>{{ L.TZ_NOTE }}</span>
      </div>
    </div>

    <!-- Loading / error states -->
    <div
      v-if="loading"
      class="flex items-center justify-center rounded-xl border border-n-weak bg-n-solid-1 py-12 text-n-slate-11"
    >
      {{ L.LOADING }}
    </div>
    <div
      v-else-if="error"
      class="rounded-xl bg-n-ruby-2 px-4 py-3 text-n-ruby-12 ring-1 ring-n-ruby-6"
    >
      {{ error }}
    </div>

    <template v-else-if="summary">
      <!-- Fairness banner — only when the data mixes strictness levels -->
      <div
        v-if="mixedLevels"
        class="flex items-start gap-3 rounded-xl bg-n-amber-2 px-4 py-3 ring-1 ring-n-amber-6"
      >
        <span
          class="i-lucide-scale mt-0.5 size-4 shrink-0 text-n-amber-11"
          aria-hidden="true"
        />
        <div class="text-[12.5px] leading-relaxed text-n-amber-12">
          <p class="font-semibold">{{ L.FAIR_TITLE }}</p>
          <p class="mt-0.5">
            {{ L.FAIR_LEVELS }}:
            <span class="font-bold">{{ strictnessLevels.join('، ') }}</span> —
            {{ L.FAIR_HINT }}
          </p>
          <p v-if="modelsUsed.length" class="mt-0.5 text-n-amber-11">
            {{ L.MODELS }}: {{ modelsUsed.join('، ') }}
          </p>
        </div>
      </div>

      <!-- Summary KPI tiles -->
      <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
          <p
            class="text-[11px] font-bold uppercase tracking-wider text-n-slate-11"
          >
            {{ L.TOTAL_CHECKS }}
          </p>
          <p
            class="mt-2 text-[28px] font-semibold tabular-nums text-n-slate-12"
          >
            {{ summary.total_checks.toLocaleString('en') }}
          </p>
        </div>
        <div
          class="rounded-xl border border-n-weak bg-n-ruby-2 p-4 ring-1 ring-n-ruby-6"
        >
          <p
            class="text-[11px] font-bold uppercase tracking-wider text-n-ruby-11"
          >
            {{ L.TOTAL_FIXES }}
          </p>
          <p class="mt-2 text-[28px] font-semibold tabular-nums text-n-ruby-12">
            {{ totalFixes.toLocaleString('en') }}
          </p>
        </div>
        <div
          class="rounded-xl border border-n-weak bg-n-teal-2 p-4 ring-1 ring-n-teal-6"
        >
          <p
            class="text-[11px] font-bold uppercase tracking-wider text-n-teal-11"
          >
            {{ L.CORRECTED }}
          </p>
          <p class="mt-2 text-[28px] font-semibold tabular-nums text-n-teal-12">
            {{ (summary.decisions.corrected || 0).toLocaleString('en') }}
          </p>
        </div>
        <div
          class="rounded-xl border border-n-weak bg-n-amber-2 p-4 ring-1 ring-n-amber-6"
        >
          <p
            class="text-[11px] font-bold uppercase tracking-wider text-n-amber-11"
          >
            {{ L.SENT_ORIGINAL }}
          </p>
          <p
            class="mt-2 text-[28px] font-semibold tabular-nums text-n-amber-12"
          >
            {{ (summary.decisions.sent_original || 0).toLocaleString('en') }}
          </p>
        </div>
      </div>

      <!-- Global category breakdown -->
      <div
        v-if="globalCategories.length"
        class="rounded-xl border border-n-weak bg-n-solid-1 p-5"
      >
        <h2 class="text-[15px] font-semibold text-n-slate-12">
          {{ L.CATEGORIES_TITLE }}
        </h2>
        <p class="mt-1 text-[12px] text-n-slate-11">{{ L.CATEGORIES_HINT }}</p>
        <!-- Proportion bar -->
        <div
          class="mt-4 flex h-3 w-full overflow-hidden rounded-full bg-n-alpha-2"
        >
          <span
            v-for="[cat, n] in globalCategories"
            :key="cat"
            :class="categoryDot(cat)"
            :style="{ width: (100 * n) / totalFixes + '%' }"
            :title="`${categoryLabel(cat)}: ${n}`"
          />
        </div>
        <div class="mt-4 flex flex-wrap gap-2">
          <span
            v-for="[cat, n] in globalCategories"
            :key="cat"
            class="inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-[12px] font-medium"
            :class="categoryChip(cat)"
          >
            <span class="size-2 rounded-full" :class="categoryDot(cat)" />
            {{ categoryLabel(cat) }}
            <span class="font-bold tabular-nums">{{ n }}</span>
          </span>
        </div>
      </div>

      <!-- Per-agent comparison -->
      <div class="rounded-xl border border-n-weak bg-n-solid-1">
        <div class="border-b border-n-weak px-5 py-3">
          <h2 class="text-[15px] font-semibold text-n-slate-12">
            {{ L.COMPARE }}
          </h2>
          <p class="mt-1 text-[12px] text-n-slate-11">{{ L.COMPARE_HINT }}</p>
        </div>

        <div
          v-if="!byAgent.length"
          class="px-5 py-8 text-center text-n-slate-11"
        >
          {{ L.EMPTY }}
        </div>

        <table v-else class="w-full text-[13px]">
          <thead>
            <tr
              class="border-b border-n-weak text-[11px] uppercase tracking-wider text-n-slate-11"
            >
              <th class="px-5 py-3 text-right font-semibold">
                {{ L.COL_AGENT }}
              </th>
              <th class="px-3 py-3 text-center font-semibold tabular-nums">
                {{ L.COL_TOTAL }}
              </th>
              <th class="px-3 py-3 text-center font-semibold tabular-nums">
                {{ L.COL_ERR_RATE }}
              </th>
              <th class="px-3 py-3 text-center font-semibold tabular-nums">
                {{ L.COL_ERRORS }}
              </th>
              <th class="px-3 py-3 text-center font-semibold">
                {{ L.COL_BEHAVIOR }}
              </th>
              <th class="px-5 py-3 text-center font-semibold tabular-nums">
                {{ L.COL_RATE }}
              </th>
            </tr>
          </thead>
          <tbody>
            <!-- eslint-disable-next-line vue/no-v-for-template-key -->
            <template v-for="agent in byAgent" :key="agentKey(agent)">
              <tr
                class="cursor-pointer border-b border-n-weak/60 hover:bg-n-alpha-1"
                @click="toggleAgent(agent)"
              >
                <td class="px-5 py-3">
                  <div class="flex items-center gap-2">
                    <span
                      class="i-lucide-chevron-left size-4 text-n-slate-10 transition-transform"
                      :class="isExpanded(agent) ? '-rotate-90' : ''"
                      aria-hidden="true"
                    />
                    <div>
                      <p class="font-semibold text-n-slate-12">
                        {{ agent.name }}
                      </p>
                      <p
                        v-if="agent.email"
                        class="mt-0.5 text-[11px] text-n-slate-10"
                      >
                        {{ agent.email }}
                      </p>
                    </div>
                  </div>
                </td>
                <td
                  class="px-3 py-3 text-center text-[14px] font-semibold tabular-nums text-n-slate-12"
                >
                  {{ agent.total }}
                </td>
                <td
                  class="px-3 py-3 text-center text-[14px] font-semibold tabular-nums"
                  :class="
                    errorRate(agent) >= 40
                      ? 'text-n-ruby-11'
                      : 'text-n-slate-11'
                  "
                >
                  {{ errorRate(agent) }}%
                </td>
                <td
                  class="px-3 py-3 text-center text-[14px] font-semibold tabular-nums text-n-ruby-11"
                >
                  {{ agent.errors_caught }}
                </td>
                <td class="px-3 py-3">
                  <div
                    class="flex h-4 overflow-hidden rounded-full bg-n-alpha-2"
                    :style="{
                      width:
                        ((100 * agent.total) / maxAgentTotal).toFixed(1) + '%',
                    }"
                  >
                    <span
                      v-if="agent.decisions.corrected"
                      class="bg-n-teal-9"
                      :style="{ width: correctedRate(agent) + '%' }"
                      :title="`قبل التصحيح: ${agent.decisions.corrected}`"
                    />
                    <span
                      v-if="agent.decisions.sent_original"
                      class="bg-n-ruby-9"
                      :style="{ width: sentOriginalRate(agent) + '%' }"
                      :title="`أرسل الأصلي: ${agent.decisions.sent_original}`"
                    />
                    <span
                      v-if="agent.decisions.edited"
                      class="bg-n-amber-9"
                      :style="{ width: editedRate(agent) + '%' }"
                      :title="`رجع للتعديل: ${agent.decisions.edited}`"
                    />
                  </div>
                  <div
                    class="mt-1.5 flex gap-3 text-[10.5px] font-medium tabular-nums"
                  >
                    <span class="text-n-teal-11"
                      >{{ '✓ ' }}{{ correctedRate(agent) }}{{ '%' }}</span
                    >
                    <span class="text-n-ruby-11"
                      >{{ '! ' }}{{ sentOriginalRate(agent) }}{{ '%' }}</span
                    >
                    <span class="text-n-amber-11"
                      >{{ '✎ ' }}{{ editedRate(agent) }}{{ '%' }}</span
                    >
                  </div>
                </td>
                <td
                  class="px-5 py-3 text-center text-[14px] font-semibold tabular-nums"
                  :class="
                    correctedRate(agent) >= 50
                      ? 'text-n-teal-11'
                      : 'text-n-slate-11'
                  "
                >
                  {{ correctedRate(agent) }}%
                </td>
              </tr>
              <!-- Drill-down -->
              <tr
                v-if="isExpanded(agent)"
                :key="`${agentKey(agent)}-detail`"
                class="border-b border-n-weak/60"
              >
                <td colspan="6" class="bg-n-alpha-1 px-5 py-4">
                  <div class="grid gap-5 md:grid-cols-2">
                    <!-- Agent category mix -->
                    <div>
                      <p
                        class="mb-2 text-[11px] font-bold uppercase tracking-wider text-n-slate-11"
                      >
                        {{ L.AGENT_CATEGORIES }}
                      </p>
                      <div
                        v-if="agentCategories(agent).length"
                        class="flex flex-wrap gap-2"
                      >
                        <span
                          v-for="[cat, n] in agentCategories(agent)"
                          :key="cat"
                          class="inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[11.5px] font-medium"
                          :class="categoryChip(cat)"
                        >
                          <span
                            class="size-2 rounded-full"
                            :class="categoryDot(cat)"
                          />
                          {{ categoryLabel(cat) }}
                          <span class="font-bold tabular-nums">{{ n }}</span>
                        </span>
                      </div>
                      <p v-else class="text-[12px] text-n-slate-10">
                        {{ L.NO_MISTAKES }}
                      </p>
                    </div>
                    <!-- Agent top mistakes -->
                    <div>
                      <p
                        class="mb-2 text-[11px] font-bold uppercase tracking-wider text-n-slate-11"
                      >
                        {{ L.AGENT_TOP }}
                      </p>
                      <ul
                        v-if="agent.top_mistakes && agent.top_mistakes.length"
                        class="flex flex-col gap-1.5"
                      >
                        <li
                          v-for="(m, i) in agent.top_mistakes"
                          :key="i"
                          class="flex items-center gap-2 text-[13px]"
                        >
                          <span
                            class="rounded bg-n-ruby-3 px-1.5 py-0.5 font-semibold text-n-ruby-12"
                            >{{ m.wrong }}</span
                          >
                          <span
                            class="i-lucide-arrow-left size-3.5 text-n-slate-9"
                            aria-hidden="true"
                          />
                          <span
                            class="rounded bg-n-teal-3 px-1.5 py-0.5 font-semibold text-n-teal-12"
                            >{{ m.right }}</span
                          >
                          <span class="text-[11px] text-n-slate-10"
                            >{{ m.count }} {{ L.TIMES }}</span
                          >
                        </li>
                      </ul>
                      <p v-else class="text-[12px] text-n-slate-10">
                        {{ L.NO_MISTAKES }}
                      </p>
                    </div>
                  </div>

                  <!-- Full corrections table -->
                  <div class="mt-5">
                    <p
                      class="mb-3 text-[11px] font-bold uppercase tracking-wider text-n-slate-11"
                    >
                      {{ L.CORR_TITLE }}
                      <span
                        v-if="agentCorrections[agentKey(agent)]"
                        class="ms-1 font-bold tabular-nums text-n-brand"
                      >
                        ({{ agentCorrections[agentKey(agent)].length }})
                      </span>
                    </p>

                    <div
                      v-if="correctionsLoading[agentKey(agent)]"
                      class="py-4 text-center text-[12px] text-n-slate-11"
                    >
                      {{ L.CORR_LOADING }}
                    </div>

                    <div
                      v-else-if="
                        agentCorrections[agentKey(agent)] &&
                        agentCorrections[agentKey(agent)].length
                      "
                      class="overflow-hidden rounded-lg border border-n-weak"
                    >
                      <div class="max-h-[400px] overflow-y-auto">
                        <table class="w-full text-[12.5px]">
                          <thead class="sticky top-0 z-10 bg-n-solid-2">
                            <tr
                              class="border-b border-n-weak text-[10px] uppercase tracking-wider text-n-slate-11"
                            >
                              <th
                                class="px-3 py-2 text-center font-semibold w-8"
                              >
                                #
                              </th>
                              <th class="px-3 py-2 text-right font-semibold">
                                {{ L.CORR_WRONG }}
                              </th>
                              <th class="w-6" />
                              <th class="px-3 py-2 text-right font-semibold">
                                {{ L.CORR_RIGHT }}
                              </th>
                              <th class="px-3 py-2 text-center font-semibold">
                                {{ L.CORR_DECISION }}
                              </th>
                              <th class="px-3 py-2 text-center font-semibold">
                                {{ L.CORR_CATEGORY }}
                              </th>
                              <th
                                class="px-3 py-2 text-center font-semibold"
                                dir="ltr"
                              >
                                {{ L.CORR_DATE }}
                              </th>
                              <th class="px-3 py-2 text-center font-semibold">
                                {{ L.CORR_CONV }}
                              </th>
                            </tr>
                          </thead>
                          <tbody>
                            <tr
                              v-for="(c, ci) in agentCorrections[
                                agentKey(agent)
                              ]"
                              :key="ci"
                              class="border-b border-n-weak/40 hover:bg-n-alpha-1"
                            >
                              <td
                                class="px-3 py-2 text-center tabular-nums text-n-slate-10 font-medium"
                              >
                                {{ ci + 1 }}
                              </td>
                              <td class="px-3 py-2">
                                <span
                                  class="rounded bg-n-ruby-3 px-1.5 py-0.5 font-semibold text-n-ruby-12"
                                  >{{ c.wrong }}</span
                                >
                              </td>
                              <td class="px-1 text-center">
                                <span
                                  class="i-lucide-arrow-left size-3 text-n-slate-9"
                                />
                              </td>
                              <td class="px-3 py-2">
                                <span
                                  class="rounded bg-n-teal-3 px-1.5 py-0.5 font-semibold text-n-teal-12"
                                  >{{ c.right }}</span
                                >
                              </td>
                              <td class="px-3 py-2 text-center">
                                <span
                                  class="inline-flex items-center gap-1 text-[11px] font-medium"
                                  :class="decisionMeta(c.decision).cls"
                                >
                                  <span
                                    :class="decisionMeta(c.decision).icon"
                                    class="size-3.5"
                                  />
                                  {{ decisionMeta(c.decision).label }}
                                </span>
                              </td>
                              <td class="px-3 py-2 text-center">
                                <span
                                  class="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10.5px] font-medium"
                                  :class="categoryChip(c.category)"
                                >
                                  <span
                                    class="size-1.5 rounded-full"
                                    :class="categoryDot(c.category)"
                                  />
                                  {{ categoryLabel(c.category) }}
                                </span>
                              </td>
                              <td
                                class="px-3 py-2 text-center text-[11px] tabular-nums text-n-slate-10"
                                dir="ltr"
                              >
                                {{ fmtDate(c.created_at) }}
                              </td>
                              <td class="px-3 py-2 text-center">
                                <a
                                  v-if="
                                    convUrl(c.conversation_id, c.message_id)
                                  "
                                  :href="
                                    convUrl(c.conversation_id, c.message_id)
                                  "
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  class="inline-flex items-center gap-1 rounded-md bg-n-brand/10 px-2 py-1 text-[10.5px] font-medium text-n-brand transition-colors hover:bg-n-brand/20"
                                >
                                  <span class="i-lucide-external-link size-3" />
                                  {{ `#${c.conversation_id}` }}
                                </a>
                                <span v-else class="text-[10px] text-n-slate-9">
                                  {{ '—' }}
                                </span>
                              </td>
                            </tr>
                          </tbody>
                        </table>
                      </div>
                    </div>

                    <p
                      v-else-if="agentCorrections[agentKey(agent)]"
                      class="text-[12px] text-n-slate-10"
                    >
                      {{ L.NO_MISTAKES }}
                    </p>
                  </div>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>

      <!-- Global top mistakes -->
      <div
        v-if="topMistakes.length"
        class="rounded-xl border border-n-weak bg-n-solid-1 p-5"
      >
        <h2 class="text-[15px] font-semibold text-n-slate-12">
          {{ L.TOP_TITLE }}
        </h2>
        <p class="mt-1 text-[12px] text-n-slate-11">{{ L.TOP_HINT }}</p>
        <ul class="mt-4 grid gap-2 sm:grid-cols-2">
          <li
            v-for="(m, i) in topMistakes"
            :key="i"
            class="flex items-center gap-2 rounded-lg bg-n-alpha-1 px-3 py-2 text-[13px]"
          >
            <span
              class="w-5 text-[12px] font-bold tabular-nums text-n-slate-10"
              >{{ i + 1 }}</span
            >
            <span
              class="rounded bg-n-ruby-3 px-1.5 py-0.5 font-semibold text-n-ruby-12"
              >{{ m.wrong }}</span
            >
            <span
              class="i-lucide-arrow-left size-3.5 text-n-slate-9"
              aria-hidden="true"
            />
            <span
              class="rounded bg-n-teal-3 px-1.5 py-0.5 font-semibold text-n-teal-12"
              >{{ m.right }}</span
            >
            <span
              class="ms-auto inline-flex items-center gap-1.5 text-[11px] text-n-slate-10"
            >
              <span
                class="size-1.5 rounded-full"
                :class="categoryDot(m.category)"
              />
              {{ categoryLabel(m.category) }}
              <span class="font-bold text-n-slate-11">{{ m.count }}</span>
            </span>
          </li>
        </ul>
      </div>

      <!-- Daily activity trend -->
      <div
        v-if="byDay.length"
        class="rounded-xl border border-n-weak bg-n-solid-1 p-5"
      >
        <h2 class="text-[15px] font-semibold text-n-slate-12">
          {{ L.TREND_TITLE }}
        </h2>
        <div class="mt-4 flex h-[120px] items-end gap-1.5">
          <div
            v-for="d in byDay"
            :key="d.date"
            class="group/bar flex h-full flex-1 flex-col items-center justify-end gap-1"
          >
            <span
              class="text-[10px] tabular-nums text-n-slate-10 opacity-0 group-hover/bar:opacity-100"
            >
              {{ dayTotal(d) }}
            </span>
            <div
              class="w-full rounded-t bg-n-brand/70 transition-colors group-hover/bar:bg-n-brand"
              :style="{
                height: (100 * dayTotal(d)) / maxDayTotal + '%',
                minHeight: dayTotal(d) ? '3px' : '0',
              }"
              :title="`${d.date}: ${dayTotal(d)}`"
            />
            <span class="text-[9px] tabular-nums text-n-slate-9">
              {{ dayLabel(d.date) }}
            </span>
          </div>
        </div>
      </div>

      <!-- Legend -->
      <div
        class="flex flex-wrap items-center gap-4 rounded-xl bg-n-alpha-1 px-4 py-3 text-[12px] text-n-slate-11"
      >
        <span class="inline-flex items-center gap-1.5">
          <span class="size-2.5 rounded-full bg-n-teal-9" />
          {{ L.LEGEND_CORRECTED }}
        </span>
        <span class="inline-flex items-center gap-1.5">
          <span class="size-2.5 rounded-full bg-n-ruby-9" />
          {{ L.LEGEND_SENT }}
        </span>
        <span class="inline-flex items-center gap-1.5">
          <span class="size-2.5 rounded-full bg-n-amber-9" />
          {{ L.LEGEND_EDITED }}
        </span>
      </div>
    </template>
  </div>
</template>
