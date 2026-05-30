<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import AgentActivityReportsAPI from 'dashboard/api/agentActivityReports';

// Eltafouk-only Arabic-first page — all visible copy lives in this L
// object so the @intlify lint rule treats them as script data rather than
// bare template strings. Ships in Arabic only; no en.json round-trip.
const L = {
  TITLE: 'تقرير نشاط الموظفين',
  SUBTITLE:
    'مين كان شغّال وكل واحد رد كام — ردود الخاص والكومنتات، القنوات، الشيفت، وسرعة الرد. بتوقيت القاهرة.',
  EXPORT: 'تصدير Excel',
  FROM: 'من',
  TO: 'إلى',
  APPLY: 'تطبيق',
  LOADING: 'جاري التحميل…',
  EMPTY: 'مفيش نشاط في الفترة المختارة.',
  // KPI tiles
  KPI_TOTAL: 'إجمالي الردود',
  KPI_DM: 'ردود الخاص',
  KPI_COMMENT: 'ردود الكومنت',
  KPI_AGENTS: 'موظفين نشطين',
  KPI_CONVS: 'محادثات',
  KPI_PEAK_HOUR: 'أكتر ساعة ضغط',
  KPI_PEAK_DAY: 'أكتر يوم ضغط',
  KPI_NOTES: 'ملاحظات داخلية',
  // sections
  HOURLY: 'النشاط على مدار اليوم',
  HOURLY_HINT: 'إجمالي ردود الفريق في كل ساعة — بيكشف ساعات التغطية الضعيفة.',
  CHANNELS: 'توزيع القنوات',
  DAILY: 'الردود يوم بيوم',
  COMPARE: 'مقارنة الموظفين',
  SYSTEM: 'حسابات النظام (مش محسوبة كموظفين)',
  UNATTR_NOTE: 'رد كومنت غير منسوب لموظف',
  WARN_PARTIAL:
    'تنبيه: الفترة دي قبل 27 مايو — ردود الكومنتات قبل التاريخ ده مش مسجّل عليها اسم الموظف، فهتظهر "غير منسوبة".',
  // table columns
  COL_AGENT: 'الموظف',
  COL_TOTAL: 'الإجمالي',
  COL_DM: 'خاص',
  COL_COMMENT: 'كومنت',
  COL_NOTES: 'ملاحظات',
  COL_CONVS: 'محادثات',
  COL_WA: 'واتساب',
  COL_FB: 'فيسبوك',
  COL_IG: 'انستجرام',
  COL_SHIFT: 'الشيفت',
  COL_FIRST_RESP: 'متوسط أول رد',
  COL_REPLY: 'متوسط زمن الرد',
  COL_DAYS: 'أيام',
  DAYS: 'أيام',
  HOUR_SUFFIX: ':00',
};

const PRESETS = [
  { key: 'today', label: 'اليوم' },
  { key: 'yesterday', label: 'أمس' },
  { key: 'week', days: 7, label: 'آخر 7 أيام' },
  { key: 'month', days: 30, label: 'آخر 30 يوم' },
];

const CHANNEL_META = [
  { key: 'whatsapp', label: 'واتساب', color: 'bg-n-teal-9' },
  { key: 'facebook', label: 'فيسبوك', color: 'bg-n-blue-9' },
  { key: 'instagram', label: 'انستجرام', color: 'bg-n-ruby-9' },
  { key: 'comments', label: 'كومنت', color: 'bg-n-amber-9' },
];

const activePreset = ref('today');
const isCustom = ref(false);
const customFrom = ref('');
const customTo = ref('');

const report = ref(null);
const loading = ref(false);
const error = ref(null);

const isoDate = d => d.toISOString().slice(0, 10);

const rangeIso = computed(() => {
  const now = new Date();
  if (isCustom.value) {
    return {
      since: customFrom.value || isoDate(now),
      until: customTo.value || isoDate(now),
    };
  }
  const preset = PRESETS.find(p => p.key === activePreset.value);
  if (preset?.key === 'today')
    return { since: isoDate(now), until: isoDate(now) };
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
    const { data } = await AgentActivityReportsAPI.fetch(rangeIso.value);
    report.value = data;
  } catch (e) {
    error.value = e.message || 'فشل التحميل';
  } finally {
    loading.value = false;
  }
};

onMounted(fetchReport);
watch(activePreset, () => {
  if (!isCustom.value) fetchReport();
});

const pickPreset = key => {
  activePreset.value = key;
  isCustom.value = false;
};
const applyCustom = () => {
  isCustom.value = true;
  fetchReport();
};

const summary = computed(() => report.value?.summary || null);
const meta = computed(() => report.value?.meta || null);
const byHour = computed(() => report.value?.by_hour || []);
const byDay = computed(() => report.value?.by_day || []);
const byChannel = computed(() => report.value?.by_channel || {});
const allAgents = computed(() => report.value?.by_agent || []);
const mainAgents = computed(() => allAgents.value.filter(a => !a.system));
const systemAgents = computed(() =>
  allAgents.value.filter(a => a.system && a.total > 0)
);

const maxHour = computed(() => Math.max(1, ...byHour.value));
const maxDay = computed(() => Math.max(1, ...byDay.value.map(d => d.total)));
const maxChannel = computed(() =>
  Math.max(1, ...CHANNEL_META.map(c => byChannel.value[c.key] || 0))
);
const maxAgentTotal = computed(() =>
  Math.max(1, ...mainAgents.value.map(a => a.total))
);

const fmtInt = n => (n || 0).toLocaleString('en');
const fmtSecs = s => {
  if (s == null) return '—';
  if (s < 60) return `${s} ث`;
  if (s < 3600) return `${Math.round(s / 60)} د`;
  return `${(s / 3600).toFixed(1)} س`;
};
const peakHourLabel = computed(() => {
  const h = summary.value?.busiest_hour;
  return h ? `${h.hour}${L.HOUR_SUFFIX}` : '—';
});
const peakDayLabel = computed(() => summary.value?.busiest_day?.date || '—');
const unattrLabel = computed(() =>
  summary.value
    ? `+${fmtInt(summary.value.unattributed_comments)} ${L.UNATTR_NOTE}`
    : ''
);
const systemBreakdown = a =>
  `${fmtInt(a.total)} (${L.COL_DM} ${fmtInt(a.dm)} / ${L.COL_COMMENT} ${fmtInt(a.comment)})`;

const shiftLabel = a => {
  if (a.active_days === 1 && a.daily[0]) {
    return `${a.daily[0].shift_start} – ${a.daily[0].shift_end}`;
  }
  return `${a.active_days} ${L.DAYS}`;
};
const shiftTitle = a =>
  a.daily
    .map(d => `${d.date}: ${d.shift_start}–${d.shift_end} (${d.total})`)
    .join('\n');

const csvCell = v => {
  const s = String(v ?? '');
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};
const exportCsv = () => {
  const header = [
    L.COL_AGENT,
    'Email',
    L.COL_TOTAL,
    L.COL_DM,
    L.COL_COMMENT,
    L.COL_NOTES,
    L.COL_CONVS,
    L.COL_WA,
    L.COL_FB,
    L.COL_IG,
    L.COL_FIRST_RESP,
    L.COL_REPLY,
    L.COL_DAYS,
  ];
  const rows = [...mainAgents.value, ...systemAgents.value].map(a => [
    a.name,
    a.email || '',
    a.total,
    a.dm,
    a.comment,
    a.notes,
    a.conversations,
    a.by_channel.whatsapp,
    a.by_channel.facebook,
    a.by_channel.instagram,
    a.avg_first_response_secs ?? '',
    a.avg_reply_secs ?? '',
    a.active_days,
  ]);
  const csv = [header, ...rows].map(r => r.map(csvCell).join(',')).join('\n');
  // Prepend a UTF-8 BOM so Excel opens the Arabic columns correctly.
  const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `agent-activity-${rangeIso.value.since}_${rangeIso.value.until}.csv`;
  link.click();
  URL.revokeObjectURL(url);
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
        <p class="mt-1 text-[13px] text-n-slate-11">{{ L.SUBTITLE }}</p>
      </div>
      <button
        v-if="summary"
        type="button"
        class="shrink-0 rounded-md bg-n-alpha-2 px-3 py-2 text-[12.5px] font-medium text-n-slate-12 hover:bg-n-alpha-3"
        @click="exportCsv"
      >
        {{ L.EXPORT }}
      </button>
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
      <!-- Partial-attribution warning -->
      <div
        v-if="meta?.comment_attribution_partial"
        class="rounded-xl bg-n-amber-2 px-4 py-3 text-[12.5px] text-n-amber-12 ring-1 ring-n-amber-6"
      >
        {{ L.WARN_PARTIAL }}
      </div>

      <!-- KPI tiles -->
      <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
          <p
            class="text-[11px] font-bold uppercase tracking-wider text-n-slate-11"
          >
            {{ L.KPI_TOTAL }}
          </p>
          <p
            class="mt-2 text-[28px] font-semibold tabular-nums text-n-slate-12"
          >
            {{ fmtInt(summary.total_replies) }}
          </p>
        </div>
        <div
          class="rounded-xl border border-n-weak bg-n-teal-2 p-4 ring-1 ring-n-teal-6"
        >
          <p
            class="text-[11px] font-bold uppercase tracking-wider text-n-teal-11"
          >
            {{ L.KPI_DM }}
          </p>
          <p class="mt-2 text-[28px] font-semibold tabular-nums text-n-teal-12">
            {{ fmtInt(summary.dm_replies) }}
          </p>
        </div>
        <div
          class="rounded-xl border border-n-weak bg-n-amber-2 p-4 ring-1 ring-n-amber-6"
        >
          <p
            class="text-[11px] font-bold uppercase tracking-wider text-n-amber-11"
          >
            {{ L.KPI_COMMENT }}
          </p>
          <p
            class="mt-2 text-[28px] font-semibold tabular-nums text-n-amber-12"
          >
            {{ fmtInt(summary.comment_replies) }}
          </p>
          <p
            v-if="summary.unattributed_comments"
            class="mt-1 text-[11px] text-n-amber-11"
          >
            {{ unattrLabel }}
          </p>
        </div>
        <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
          <p
            class="text-[11px] font-bold uppercase tracking-wider text-n-slate-11"
          >
            {{ L.KPI_AGENTS }}
          </p>
          <p
            class="mt-2 text-[28px] font-semibold tabular-nums text-n-slate-12"
          >
            {{ fmtInt(summary.active_agents) }}
          </p>
        </div>
        <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
          <p
            class="text-[11px] font-bold uppercase tracking-wider text-n-slate-11"
          >
            {{ L.KPI_CONVS }}
          </p>
          <p
            class="mt-2 text-[28px] font-semibold tabular-nums text-n-slate-12"
          >
            {{ fmtInt(summary.total_conversations) }}
          </p>
        </div>
        <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
          <p
            class="text-[11px] font-bold uppercase tracking-wider text-n-slate-11"
          >
            {{ L.KPI_PEAK_HOUR }}
          </p>
          <p
            class="mt-2 text-[28px] font-semibold tabular-nums text-n-slate-12"
          >
            {{ peakHourLabel }}
          </p>
        </div>
        <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
          <p
            class="text-[11px] font-bold uppercase tracking-wider text-n-slate-11"
          >
            {{ L.KPI_PEAK_DAY }}
          </p>
          <p
            class="mt-2 text-[18px] font-semibold tabular-nums text-n-slate-12"
          >
            {{ peakDayLabel }}
          </p>
        </div>
        <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
          <p
            class="text-[11px] font-bold uppercase tracking-wider text-n-slate-11"
          >
            {{ L.KPI_NOTES }}
          </p>
          <p
            class="mt-2 text-[28px] font-semibold tabular-nums text-n-slate-12"
          >
            {{ fmtInt(summary.notes) }}
          </p>
        </div>
      </div>

      <!-- Hourly heatmap -->
      <div class="rounded-xl border border-n-weak bg-n-solid-1 p-5">
        <h2 class="text-[15px] font-semibold text-n-slate-12">
          {{ L.HOURLY }}
        </h2>
        <p class="mt-1 text-[12px] text-n-slate-11">{{ L.HOURLY_HINT }}</p>
        <div class="mt-4 flex h-[120px] items-end gap-1">
          <div
            v-for="(count, hour) in byHour"
            :key="hour"
            class="min-h-px flex-1 rounded-t bg-n-brand/80"
            :style="{ height: `${maxHour ? (100 * count) / maxHour : 0}%` }"
            :title="`${hour}${L.HOUR_SUFFIX} — ${count}`"
          />
        </div>
        <div class="mt-1 flex gap-1">
          <span
            v-for="(count, hour) in byHour"
            :key="hour"
            class="flex-1 text-center text-[9px] tabular-nums text-n-slate-10"
          >
            {{ hour }}
          </span>
        </div>
      </div>

      <!-- Channels + Daily side by side -->
      <div class="grid gap-4 lg:grid-cols-2">
        <div class="rounded-xl border border-n-weak bg-n-solid-1 p-5">
          <h2 class="text-[15px] font-semibold text-n-slate-12">
            {{ L.CHANNELS }}
          </h2>
          <div class="mt-4 flex flex-col gap-3">
            <div
              v-for="c in CHANNEL_META"
              :key="c.key"
              class="flex items-center gap-3"
            >
              <span class="w-16 text-[12px] text-n-slate-11">{{
                c.label
              }}</span>
              <div class="h-3 flex-1 overflow-hidden rounded-full bg-n-alpha-2">
                <div
                  class="h-full rounded-full"
                  :class="c.color"
                  :style="{
                    width: `${(100 * (byChannel[c.key] || 0)) / maxChannel}%`,
                  }"
                />
              </div>
              <span
                class="w-14 text-left text-[12px] font-semibold tabular-nums text-n-slate-12"
              >
                {{ fmtInt(byChannel[c.key]) }}
              </span>
            </div>
          </div>
        </div>

        <div
          v-if="byDay.length > 1"
          class="rounded-xl border border-n-weak bg-n-solid-1 p-5"
        >
          <h2 class="text-[15px] font-semibold text-n-slate-12">
            {{ L.DAILY }}
          </h2>
          <div class="mt-4 flex h-[140px] items-end gap-2">
            <div
              v-for="d in byDay"
              :key="d.date"
              class="min-h-px flex-1 rounded-t bg-n-teal-9"
              :style="{ height: `${maxDay ? (100 * d.total) / maxDay : 0}%` }"
              :title="`${d.date} — ${d.total}`"
            />
          </div>
          <div class="mt-1 flex gap-2">
            <span
              v-for="d in byDay"
              :key="d.date"
              class="flex-1 text-center text-[9px] tabular-nums text-n-slate-10"
            >
              {{ d.date.slice(5) }}
            </span>
          </div>
        </div>
      </div>

      <!-- Agent comparison table -->
      <div class="rounded-xl border border-n-weak bg-n-solid-1">
        <div class="border-b border-n-weak px-5 py-3">
          <h2 class="text-[15px] font-semibold text-n-slate-12">
            {{ L.COMPARE }}
          </h2>
        </div>
        <div
          v-if="!mainAgents.length"
          class="px-5 py-8 text-center text-n-slate-11"
        >
          {{ L.EMPTY }}
        </div>
        <div v-else class="overflow-x-auto">
          <table class="w-full min-w-[860px] text-[13px]">
            <thead>
              <tr
                class="border-b border-n-weak text-[11px] uppercase tracking-wider text-n-slate-11"
              >
                <th class="px-4 py-3 text-right font-semibold">
                  {{ L.COL_AGENT }}
                </th>
                <th class="px-2 py-3 text-center font-semibold">
                  {{ L.COL_TOTAL }}
                </th>
                <th class="px-2 py-3 text-center font-semibold">
                  {{ L.COL_DM }}
                </th>
                <th class="px-2 py-3 text-center font-semibold">
                  {{ L.COL_COMMENT }}
                </th>
                <th class="px-2 py-3 text-center font-semibold">
                  {{ L.COL_NOTES }}
                </th>
                <th class="px-2 py-3 text-center font-semibold">
                  {{ L.COL_CONVS }}
                </th>
                <th class="px-2 py-3 text-center font-semibold">
                  {{ L.COL_WA }}
                </th>
                <th class="px-2 py-3 text-center font-semibold">
                  {{ L.COL_FB }}
                </th>
                <th class="px-2 py-3 text-center font-semibold">
                  {{ L.COL_IG }}
                </th>
                <th class="px-3 py-3 text-center font-semibold">
                  {{ L.COL_SHIFT }}
                </th>
                <th class="px-2 py-3 text-center font-semibold">
                  {{ L.COL_FIRST_RESP }}
                </th>
                <th class="px-2 py-3 text-center font-semibold">
                  {{ L.COL_REPLY }}
                </th>
                <th class="px-2 py-3 text-center font-semibold">
                  {{ L.COL_DAYS }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="a in mainAgents"
                :key="a.user_id"
                class="border-b border-n-weak/60 last:border-0 hover:bg-n-alpha-1"
              >
                <td class="px-4 py-3">
                  <p class="font-semibold text-n-slate-12">{{ a.name }}</p>
                  <div
                    class="mt-1 h-1.5 w-28 overflow-hidden rounded-full bg-n-alpha-2"
                  >
                    <div
                      class="h-full rounded-full bg-n-brand"
                      :style="{ width: `${(100 * a.total) / maxAgentTotal}%` }"
                    />
                  </div>
                </td>
                <td
                  class="px-2 py-3 text-center text-[14px] font-semibold tabular-nums text-n-slate-12"
                >
                  {{ fmtInt(a.total) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-teal-11">
                  {{ fmtInt(a.dm) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-amber-11">
                  {{ fmtInt(a.comment) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-10">
                  {{ fmtInt(a.notes) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-11">
                  {{ fmtInt(a.conversations) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-11">
                  {{ fmtInt(a.by_channel.whatsapp) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-11">
                  {{ fmtInt(a.by_channel.facebook) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-11">
                  {{ fmtInt(a.by_channel.instagram) }}
                </td>
                <td
                  class="px-3 py-3 text-center text-[12px] tabular-nums text-n-slate-11"
                  :title="shiftTitle(a)"
                >
                  {{ shiftLabel(a) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-11">
                  {{ fmtSecs(a.avg_first_response_secs) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-11">
                  {{ fmtSecs(a.avg_reply_secs) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-11">
                  {{ a.active_days }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- System accounts -->
      <div
        v-if="systemAgents.length"
        class="rounded-xl border border-n-weak bg-n-alpha-1"
      >
        <div class="border-b border-n-weak px-5 py-3">
          <h2 class="text-[13px] font-semibold text-n-slate-11">
            {{ L.SYSTEM }}
          </h2>
        </div>
        <table class="w-full text-[13px]">
          <tbody>
            <tr
              v-for="a in systemAgents"
              :key="a.user_id"
              class="border-b border-n-weak/60 last:border-0"
            >
              <td class="px-5 py-2.5 text-n-slate-11">{{ a.name }}</td>
              <td class="px-3 py-2.5 text-center tabular-nums text-n-slate-11">
                {{ systemBreakdown(a) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </div>
</template>
