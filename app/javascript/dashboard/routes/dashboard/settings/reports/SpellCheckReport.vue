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
    'تتبّع الأخطاء الإملائية لكل موظف، ومين بيستخدم التصحيح ومين بيرسل النص الأصلي.',
  FROM: 'من',
  TO: 'إلى',
  APPLY: 'تطبيق',
  LOADING: 'جاري التحميل…',
  EMPTY: 'مفيش بيانات في النطاق المختار.',
  ERROR_FALLBACK: 'فشل التحميل',
  TOTAL_CHECKS: 'إجمالي الفحوصات',
  CORRECTED: 'تصحيحات مقبولة',
  SENT_ORIGINAL: 'أُرسل النص الأصلي',
  EDITED: 'رجع للتعديل',
  COMPARE: 'مقارنة الموظفين',
  COMPARE_HINT:
    'مرتّبين بعدد الفحوصات. النسبة بتعرض إيه نسبة كل قرار من إجمالي الفحوصات اللي ظهر فيها modal.',
  COL_AGENT: 'الموظف',
  COL_TOTAL: 'إجمالي',
  COL_ERRORS: 'أخطاء وقعت فيها',
  COL_BEHAVIOR: 'سلوكه',
  COL_RATE: 'معدّل قبول التصحيح',
  NO_AGENT: 'بدون موظف',
  LEGEND_CORRECTED: 'قبل التصحيح',
  LEGEND_SENT: 'أرسل الأصلي',
  LEGEND_EDITED: 'رجع للتعديل',
};

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

const allAgents = computed(() => store.getters['agents/getAgents'] || []);

const isoDate = d => d.toISOString().slice(0, 10);

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

const fetchReport = async () => {
  loading.value = true;
  error.value = null;
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

const correctedRate = a => {
  if (!a.total) return 0;
  return Math.round((100 * (a.decisions.corrected || 0)) / a.total);
};
const sentOriginalRate = a => {
  if (!a.total) return 0;
  return Math.round((100 * (a.decisions.sent_original || 0)) / a.total);
};
const editedRate = a => {
  if (!a.total) return 0;
  return Math.round((100 * (a.decisions.edited || 0)) / a.total);
};

// Find the busiest agent's total so we can scale the bar widths in the
// comparison chart without recomputing on every render.
const maxAgentTotal = computed(() =>
  byAgent.value.reduce((m, a) => Math.max(m, a.total), 1)
);

const pickPreset = key => {
  activePreset.value = key;
  isCustom.value = false;
};
const applyCustom = () => {
  isCustom.value = true;
  fetchReport();
};
</script>

<template>
  <div class="flex flex-col gap-6 p-6">
    <!-- Header -->
    <header class="flex items-start justify-between gap-4">
      <div>
        <h1 class="text-[18px] font-semibold tracking-tight text-n-slate-12">
          {{ L.TITLE }}
        </h1>
        <p class="mt-1 text-[13px] text-n-slate-11">
          {{ L.SUBTITLE }}
        </p>
      </div>
    </header>

    <!-- Filters -->
    <div
      class="flex flex-wrap items-center gap-3 rounded-xl border border-n-weak bg-n-solid-1 p-3"
    >
      <div class="flex flex-wrap gap-1">
        <button
          v-for="p in PRESETS"
          :key="p.key"
          type="button"
          class="rounded-md px-3 py-1.5 text-[12.5px] font-medium transition-colors"
          :class="
            !isCustom && activePreset === p.key
              ? 'bg-n-brand text-white'
              : 'text-n-slate-11 hover:bg-n-alpha-2'
          "
          @click="pickPreset(p.key)"
        >
          {{ p.label }}
        </button>
      </div>
      <div class="h-6 w-px bg-n-weak" />
      <div class="flex items-center gap-2 text-[12px]">
        <span class="text-n-slate-11">{{ L.FROM }}</span>
        <input
          v-model="customFrom"
          type="date"
          class="rounded-md border border-n-weak bg-n-solid-1 px-2 py-1 text-n-slate-12"
        />
        <span class="text-n-slate-11">{{ L.TO }}</span>
        <input
          v-model="customTo"
          type="date"
          class="rounded-md border border-n-weak bg-n-solid-1 px-2 py-1 text-n-slate-12"
        />
        <button
          type="button"
          class="rounded-md bg-n-alpha-2 px-3 py-1.5 text-[12.5px] font-medium text-n-slate-12 hover:bg-n-alpha-3"
          @click="applyCustom"
        >
          {{ L.APPLY }}
        </button>
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
          class="rounded-xl border border-n-weak bg-n-ruby-2 p-4 ring-1 ring-n-ruby-6"
        >
          <p
            class="text-[11px] font-bold uppercase tracking-wider text-n-ruby-11"
          >
            {{ L.SENT_ORIGINAL }}
          </p>
          <p class="mt-2 text-[28px] font-semibold tabular-nums text-n-ruby-12">
            {{ (summary.decisions.sent_original || 0).toLocaleString('en') }}
          </p>
        </div>
        <div
          class="rounded-xl border border-n-weak bg-n-amber-2 p-4 ring-1 ring-n-amber-6"
        >
          <p
            class="text-[11px] font-bold uppercase tracking-wider text-n-amber-11"
          >
            {{ L.EDITED }}
          </p>
          <p
            class="mt-2 text-[28px] font-semibold tabular-nums text-n-amber-12"
          >
            {{ (summary.decisions.edited || 0).toLocaleString('en') }}
          </p>
        </div>
      </div>

      <!-- Per-agent comparison -->
      <div class="rounded-xl border border-n-weak bg-n-solid-1">
        <div class="border-b border-n-weak px-5 py-3">
          <h2 class="text-[15px] font-semibold text-n-slate-12">
            {{ L.COMPARE }}
          </h2>
          <p class="mt-1 text-[12px] text-n-slate-11">
            {{ L.COMPARE_HINT }}
          </p>
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
            <tr
              v-for="agent in byAgent"
              :key="agent.user_id || 'na'"
              class="border-b border-n-weak/60 last:border-0 hover:bg-n-alpha-1"
            >
              <td class="px-5 py-3">
                <p class="font-semibold text-n-slate-12">{{ agent.name }}</p>
                <p
                  v-if="agent.email"
                  class="mt-0.5 text-[11px] text-n-slate-10"
                >
                  {{ agent.email }}
                </p>
              </td>
              <td
                class="px-3 py-3 text-center text-[14px] font-semibold tabular-nums text-n-slate-12"
              >
                {{ agent.total }}
              </td>
              <td
                class="px-3 py-3 text-center text-[14px] font-semibold tabular-nums text-n-ruby-11"
              >
                {{ agent.errors_caught }}
              </td>
              <td class="px-3 py-3">
                <!-- Stacked bar showing decision breakdown -->
                <div class="flex items-center gap-2">
                  <div
                    class="flex h-4 flex-1 overflow-hidden rounded-full bg-n-alpha-2"
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
          </tbody>
        </table>
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
