<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import AgentActivityReportsAPI from 'dashboard/api/agentActivityReports';

// Eltafouk-only Arabic-first page — all visible copy lives in this L
// object so the @intlify lint rule treats them as script data rather than
// bare template strings. Ships in Arabic only; no en.json round-trip.
const L = {
  TITLE: 'تقرير نشاط الموظفين',
  SUBTITLE:
    'مين كان شغّال وكل واحد رد كام — الخاص والكومنت، القنوات، الشيفت، وسرعة الرد.',
  TZ_NOTE: 'بتوقيت القاهرة',
  EXPORT: 'تصدير Excel',
  FROM: 'من',
  TO: 'إلى',
  APPLY: 'تطبيق',
  CUSTOM: 'فترة مخصصة',
  LOADING: 'جاري التحميل…',
  EMPTY: 'مفيش نشاط في الفترة المختارة.',
  KPI_TOTAL: 'إجمالي الردود',
  KPI_DM: 'ردود الخاص',
  KPI_COMMENT: 'ردود الكومنت',
  KPI_AGENTS: 'موظفين نشطين',
  KPI_CONVS: 'محادثات',
  KPI_PEAK_HOUR: 'أكتر ساعة ضغط',
  KPI_PEAK_DAY: 'أكتر يوم ضغط',
  KPI_NOTES: 'ملاحظات داخلية',
  HOURLY: 'النشاط على مدار اليوم',
  HOURLY_HINT: 'إجمالي ردود الفريق في كل ساعة — بيكشف ساعات التغطية الضعيفة.',
  CHANNELS: 'توزيع القنوات',
  DAILY: 'الردود يوم بيوم',
  COMPARE: 'مقارنة الموظفين',
  COMPARE_HINT: 'مرتّبين بإجمالي الردود.',
  SYSTEM: 'حسابات النظام',
  SYSTEM_HINT: 'مش محسوبة ضمن الموظفين.',
  UNATTR_NOTE: 'كومنت غير منسوب',
  WARN_PARTIAL:
    'الفترة دي قبل 27 مايو — ردود الكومنتات قبل التاريخ ده مش متسجّل عليها اسم الموظف، فهتظهر غير منسوبة.',
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
  COL_FIRST_RESP: 'أول رد',
  COL_REPLY: 'زمن الرد',
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
  {
    key: 'whatsapp',
    label: 'واتساب',
    icon: 'i-logos-whatsapp-icon',
    bar: 'bg-n-teal-9',
  },
  {
    key: 'facebook',
    label: 'فيسبوك',
    icon: 'i-logos-facebook',
    bar: 'bg-n-blue-9',
  },
  {
    key: 'instagram',
    label: 'انستجرام',
    icon: 'i-logos-instagram-icon',
    bar: 'bg-n-ruby-9',
  },
  {
    key: 'comments',
    label: 'كومنت',
    icon: 'i-lucide-message-square',
    bar: 'bg-n-amber-9',
  },
];

// Icon-badge tints for the KPI tiles / table accents.
const TONE = {
  brand: 'bg-n-brand/15 text-n-brand',
  teal: 'bg-n-teal-2 text-n-teal-11',
  amber: 'bg-n-amber-2 text-n-amber-11',
  blue: 'bg-n-blue-2 text-n-blue-11',
  ruby: 'bg-n-ruby-2 text-n-ruby-11',
  slate: 'bg-n-alpha-2 text-n-slate-11',
};
const AVATAR_TONES = [
  'bg-n-teal-2 text-n-teal-11',
  'bg-n-blue-2 text-n-blue-11',
  'bg-n-amber-2 text-n-amber-11',
  'bg-n-ruby-2 text-n-ruby-11',
  'bg-n-brand/15 text-n-brand',
];

const activePreset = ref('today');
const isCustom = ref(false);
const customFrom = ref('');
const customTo = ref('');

const report = ref(null);
const loading = ref(false);
const error = ref(null);

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
const channelTotal = computed(() =>
  CHANNEL_META.reduce((s, c) => s + (byChannel.value[c.key] || 0), 0)
);

const fmtInt = n => (n || 0).toLocaleString('en');
const fmtSecs = s => {
  if (s == null) return '—';
  if (s < 60) return `${s} ث`;
  if (s < 3600) return `${Math.round(s / 60)} د`;
  return `${(s / 3600).toFixed(1)} س`;
};
const fmtTime12 = timeStr => {
  if (!timeStr) return '—';
  const parts = timeStr.split(':');
  if (parts.length < 2) return timeStr;
  let h = parseInt(parts[0], 10);
  const m = parts[1];
  const ampm = h >= 12 ? 'pm' : 'am';
  h %= 12;
  if (h === 0) h = 12;
  return `${h}:${m} ${ampm}`;
};
const fmtHour12 = h => {
  if (h == null || h === -1) return '—';
  const ampm = h >= 12 ? 'pm' : 'am';
  let h12 = h % 12;
  if (h12 === 0) h12 = 12;
  return `${h12}:00 ${ampm}`;
};
const fmtHourLabel = h => {
  const ampm = h >= 12 ? 'pm' : 'am';
  let h12 = h % 12;
  if (h12 === 0) h12 = 12;
  return `${h12}${ampm}`;
};
const initials = name =>
  (name || '?')
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map(w => w[0])
    .join('');
const avatarTone = i => AVATAR_TONES[i % AVATAR_TONES.length];
const channelShare = key =>
  channelTotal.value
    ? Math.round((100 * (byChannel.value[key] || 0)) / channelTotal.value)
    : 0;

const peakHourLabel = computed(() => {
  const h = summary.value?.busiest_hour;
  return h ? fmtHour12(h.hour) : '—';
});
const peakDayLabel = computed(() => summary.value?.busiest_day?.date || '—');
const peakHour = computed(() => summary.value?.busiest_hour?.hour ?? -1);
const rangeLabel = computed(() => {
  const r = rangeIso.value;
  return r.since === r.until ? r.since : `${r.since} — ${r.until}`;
});
const unattrLabel = computed(() =>
  summary.value
    ? `+${fmtInt(summary.value.unattributed_comments)} ${L.UNATTR_NOTE}`
    : ''
);
const systemBreakdown = a =>
  `${L.COL_DM} ${fmtInt(a.dm)} · ${L.COL_COMMENT} ${fmtInt(a.comment)}`;

const kpis = computed(() => {
  const s = summary.value;
  if (!s) return [];
  return [
    {
      key: 'total',
      label: L.KPI_TOTAL,
      value: fmtInt(s.total_replies),
      icon: 'i-lucide-messages-square',
      tone: 'brand',
    },
    {
      key: 'dm',
      label: L.KPI_DM,
      value: fmtInt(s.dm_replies),
      icon: 'i-lucide-message-circle',
      tone: 'teal',
    },
    {
      key: 'comment',
      label: L.KPI_COMMENT,
      value: fmtInt(s.comment_replies),
      icon: 'i-lucide-message-square',
      tone: 'amber',
      note: s.unattributed_comments ? unattrLabel.value : '',
    },
    {
      key: 'agents',
      label: L.KPI_AGENTS,
      value: fmtInt(s.active_agents),
      icon: 'i-lucide-users',
      tone: 'blue',
    },
    {
      key: 'convs',
      label: L.KPI_CONVS,
      value: fmtInt(s.total_conversations),
      icon: 'i-lucide-inbox',
      tone: 'slate',
    },
    {
      key: 'peakh',
      label: L.KPI_PEAK_HOUR,
      value: peakHourLabel.value,
      icon: 'i-lucide-flame',
      tone: 'ruby',
    },
    {
      key: 'peakd',
      label: L.KPI_PEAK_DAY,
      value: peakDayLabel.value,
      icon: 'i-lucide-calendar-days',
      tone: 'slate',
      small: true,
    },
    {
      key: 'notes',
      label: L.KPI_NOTES,
      value: fmtInt(s.notes),
      icon: 'i-lucide-sticky-note',
      tone: 'slate',
    },
  ];
});

const shiftLabel = a => {
  if (a.active_days === 1 && a.daily[0]) {
    return `${fmtTime12(a.daily[0].shift_start)} – ${fmtTime12(a.daily[0].shift_end)}`;
  }
  return `${a.active_days} ${L.DAYS}`;
};
const shiftTitle = a =>
  a.daily
    .map(
      d =>
        `${d.date}: ${fmtTime12(d.shift_start)}–${fmtTime12(d.shift_end)} (${d.total})`
    )
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
  <div class="flex flex-col gap-5 p-6">
    <!-- Header -->
    <header class="flex flex-wrap items-start justify-between gap-4">
      <div class="flex items-center gap-3">
        <span
          class="grid size-10 place-items-center rounded-xl bg-n-brand/15 text-n-brand"
        >
          <span class="i-lucide-users-round size-5" />
        </span>
        <div>
          <h1 class="text-[18px] font-semibold tracking-tight text-n-slate-12">
            {{ L.TITLE }}
          </h1>
          <p class="mt-0.5 text-[12.5px] text-n-slate-11">{{ L.SUBTITLE }}</p>
        </div>
      </div>
      <button
        type="button"
        class="inline-flex shrink-0 items-center gap-2 rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-[12.5px] font-medium text-n-slate-12 shadow-sm transition-colors hover:bg-n-alpha-2"
        @click="exportCsv"
      >
        <span class="i-lucide-download size-4 text-n-slate-11" />
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

    <!-- Loading / error -->
    <div
      v-if="loading"
      class="flex items-center justify-center gap-2 rounded-xl border border-n-weak bg-n-solid-1 py-16 text-n-slate-11"
    >
      <span class="i-lucide-loader-circle size-4 animate-spin" />
      {{ L.LOADING }}
    </div>
    <div
      v-else-if="error"
      class="rounded-xl bg-n-ruby-2 px-4 py-3 text-n-ruby-12 ring-1 ring-n-ruby-6"
    >
      {{ error }}
    </div>

    <template v-else-if="summary">
      <!-- partial-attribution warning -->
      <div
        v-if="meta?.comment_attribution_partial"
        class="flex items-start gap-2 rounded-xl bg-n-amber-2 px-4 py-3 text-[12.5px] text-n-amber-12 ring-1 ring-n-amber-6"
      >
        <span class="i-lucide-triangle-alert mt-0.5 size-4 shrink-0" />
        <span>{{ L.WARN_PARTIAL }}</span>
      </div>

      <!-- KPI tiles -->
      <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <div
          v-for="k in kpis"
          :key="k.key"
          class="group rounded-xl border border-n-weak bg-n-solid-1 p-4 transition-all hover:border-n-slate-5 hover:shadow-sm"
        >
          <div class="flex items-center justify-between">
            <p
              class="text-[11px] font-bold uppercase tracking-wider text-n-slate-10"
            >
              {{ k.label }}
            </p>
            <span
              class="grid size-7 place-items-center rounded-lg transition-transform group-hover:scale-110"
              :class="TONE[k.tone]"
            >
              <span :class="`${k.icon} size-4`" />
            </span>
          </div>
          <p
            class="mt-2 font-semibold tabular-nums text-n-slate-12"
            :class="k.small ? 'text-[18px]' : 'text-[26px]'"
            dir="ltr"
          >
            {{ k.value }}
          </p>
          <p v-if="k.note" class="mt-0.5 text-[11px] text-n-amber-11">
            {{ k.note }}
          </p>
        </div>
      </div>

      <!-- Hourly heatmap -->
      <div class="rounded-xl border border-n-weak bg-n-solid-1 p-5">
        <div class="flex items-center gap-2">
          <span class="i-lucide-activity size-4 text-n-slate-11" />
          <h2 class="text-[15px] font-semibold text-n-slate-12">
            {{ L.HOURLY }}
          </h2>
        </div>
        <p class="mt-1 text-[12px] text-n-slate-11">{{ L.HOURLY_HINT }}</p>
        <div class="mt-5 flex h-[120px] items-end gap-1">
          <div
            v-for="(count, hour) in byHour"
            :key="hour"
            class="group min-h-px flex-1 rounded-t transition-colors"
            :class="
              hour === peakHour
                ? 'bg-n-brand'
                : 'bg-n-brand/35 hover:bg-n-brand/60'
            "
            :style="{ height: `${maxHour ? (100 * count) / maxHour : 0}%` }"
            :title="`${fmtHour12(hour)} — ${count}`"
          />
        </div>
        <div class="mt-1.5 flex gap-1">
          <span
            v-for="(count, hour) in byHour"
            :key="hour"
            class="flex-1 text-center text-[9px] tabular-nums text-n-slate-10"
          >
            {{ fmtHourLabel(hour) }}
          </span>
        </div>
      </div>

      <!-- Channels + Daily -->
      <div class="grid gap-4 lg:grid-cols-2">
        <div class="rounded-xl border border-n-weak bg-n-solid-1 p-5">
          <div class="flex items-center gap-2">
            <span class="i-lucide-share-2 size-4 text-n-slate-11" />
            <h2 class="text-[15px] font-semibold text-n-slate-12">
              {{ L.CHANNELS }}
            </h2>
          </div>
          <div class="mt-4 flex flex-col gap-3.5">
            <div
              v-for="c in CHANNEL_META"
              :key="c.key"
              class="flex items-center gap-3"
            >
              <span
                class="flex w-20 items-center gap-1.5 text-[12px] text-n-slate-11"
              >
                <span :class="`${c.icon} size-3.5`" />
                {{ c.label }}
              </span>
              <div
                class="h-2.5 flex-1 overflow-hidden rounded-full bg-n-alpha-2"
              >
                <div
                  class="h-full rounded-full transition-all duration-500"
                  :class="c.bar"
                  :style="{
                    width: `${(100 * (byChannel[c.key] || 0)) / maxChannel}%`,
                  }"
                />
              </div>
              <span
                class="w-9 text-left text-[11px] tabular-nums text-n-slate-10"
              >
                {{ channelShare(c.key) + '%' }}
              </span>
              <span
                class="w-12 text-left text-[12.5px] font-semibold tabular-nums text-n-slate-12"
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
          <div class="flex items-center gap-2">
            <span class="i-lucide-calendar-range size-4 text-n-slate-11" />
            <h2 class="text-[15px] font-semibold text-n-slate-12">
              {{ L.DAILY }}
            </h2>
          </div>
          <div class="mt-4 flex h-[140px] items-end gap-2">
            <div
              v-for="d in byDay"
              :key="d.date"
              class="min-h-px flex-1 rounded-t bg-n-teal-9 transition-opacity hover:opacity-80"
              :style="{ height: `${maxDay ? (100 * d.total) / maxDay : 0}%` }"
              :title="`${d.date} — ${d.total}`"
            />
          </div>
          <div class="mt-1.5 flex gap-2">
            <span
              v-for="d in byDay"
              :key="d.date"
              class="flex-1 text-center text-[9px] tabular-nums text-n-slate-10"
              dir="ltr"
            >
              {{ d.date.slice(5) }}
            </span>
          </div>
        </div>
      </div>

      <!-- Agent leaderboard -->
      <div class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1">
        <div
          class="flex items-center justify-between border-b border-n-weak px-5 py-3.5"
        >
          <div class="flex items-center gap-2">
            <span class="i-lucide-trophy size-4 text-n-slate-11" />
            <h2 class="text-[15px] font-semibold text-n-slate-12">
              {{ L.COMPARE }}
            </h2>
          </div>
          <span class="text-[12px] text-n-slate-10">{{ L.COMPARE_HINT }}</span>
        </div>

        <div
          v-if="!mainAgents.length"
          class="px-5 py-10 text-center text-n-slate-11"
        >
          {{ L.EMPTY }}
        </div>

        <div v-else class="overflow-x-auto">
          <table class="w-full min-w-[900px] text-[13px]">
            <thead>
              <tr
                class="border-b border-n-weak bg-n-alpha-1 text-[11px] font-semibold uppercase tracking-wider text-n-slate-10"
              >
                <th class="px-4 py-2.5 text-right">{{ L.COL_AGENT }}</th>
                <th class="px-2 py-2.5 text-center">{{ L.COL_TOTAL }}</th>
                <th class="px-2 py-2.5 text-center">{{ L.COL_DM }}</th>
                <th class="px-2 py-2.5 text-center">{{ L.COL_COMMENT }}</th>
                <th class="px-2 py-2.5 text-center">{{ L.COL_NOTES }}</th>
                <th class="px-2 py-2.5 text-center">{{ L.COL_CONVS }}</th>
                <th class="px-2 py-2.5 text-center">{{ L.COL_WA }}</th>
                <th class="px-2 py-2.5 text-center">{{ L.COL_FB }}</th>
                <th class="px-2 py-2.5 text-center">{{ L.COL_IG }}</th>
                <th class="px-3 py-2.5 text-center">{{ L.COL_SHIFT }}</th>
                <th class="px-2 py-2.5 text-center">{{ L.COL_FIRST_RESP }}</th>
                <th class="px-2 py-2.5 text-center">{{ L.COL_REPLY }}</th>
                <th class="px-2 py-2.5 text-center">{{ L.COL_DAYS }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="(a, i) in mainAgents"
                :key="a.user_id"
                class="border-b border-n-weak/60 transition-colors last:border-0 hover:bg-n-alpha-1"
                :class="i === 0 ? 'bg-n-brand/[0.03]' : ''"
              >
                <td class="px-4 py-3">
                  <div class="flex items-center gap-3">
                    <span
                      class="w-4 text-center text-[12px] font-bold tabular-nums"
                      :class="i === 0 ? 'text-n-brand' : 'text-n-slate-9'"
                    >
                      {{ i + 1 }}
                    </span>
                    <span
                      class="grid size-8 shrink-0 place-items-center rounded-full text-[11px] font-bold"
                      :class="avatarTone(i)"
                    >
                      {{ initials(a.name) }}
                    </span>
                    <div class="min-w-[120px]">
                      <p class="font-semibold text-n-slate-12">{{ a.name }}</p>
                      <div
                        class="mt-1 h-1 w-28 overflow-hidden rounded-full bg-n-alpha-2"
                      >
                        <div
                          class="h-full rounded-full"
                          :class="i === 0 ? 'bg-n-brand' : 'bg-n-slate-8'"
                          :style="{
                            width: `${(100 * a.total) / maxAgentTotal}%`,
                          }"
                        />
                      </div>
                    </div>
                  </div>
                </td>
                <td
                  class="px-2 py-3 text-center text-[15px] font-bold tabular-nums text-n-slate-12"
                >
                  {{ fmtInt(a.total) }}
                </td>
                <td
                  class="px-2 py-3 text-center font-medium tabular-nums text-n-teal-11"
                >
                  {{ fmtInt(a.dm) }}
                </td>
                <td
                  class="px-2 py-3 text-center font-medium tabular-nums text-n-amber-11"
                >
                  {{ fmtInt(a.comment) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-10">
                  {{ fmtInt(a.notes) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-11">
                  {{ fmtInt(a.conversations) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-10">
                  {{ fmtInt(a.by_channel.whatsapp) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-10">
                  {{ fmtInt(a.by_channel.facebook) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-10">
                  {{ fmtInt(a.by_channel.instagram) }}
                </td>
                <td class="px-3 py-3 text-center" :title="shiftTitle(a)">
                  <span
                    class="inline-block rounded-md bg-n-alpha-2 px-2 py-0.5 text-[11.5px] tabular-nums text-n-slate-11"
                    dir="ltr"
                  >
                    {{ shiftLabel(a) }}
                  </span>
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-11">
                  {{ fmtSecs(a.avg_first_response_secs) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-11">
                  {{ fmtSecs(a.avg_reply_secs) }}
                </td>
                <td class="px-2 py-3 text-center tabular-nums text-n-slate-10">
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
        <div class="flex items-center gap-2 border-b border-n-weak px-5 py-3">
          <span class="i-lucide-bot size-3.5 text-n-slate-10" />
          <h2 class="text-[13px] font-semibold text-n-slate-11">
            {{ L.SYSTEM }}
          </h2>
          <span class="text-[11.5px] text-n-slate-10">{{ L.SYSTEM_HINT }}</span>
        </div>
        <div class="divide-y divide-n-weak/60">
          <div
            v-for="a in systemAgents"
            :key="a.user_id"
            class="flex items-center justify-between px-5 py-2.5"
          >
            <span class="text-[13px] text-n-slate-11">{{ a.name }}</span>
            <span
              class="flex items-center gap-3 text-[12px] tabular-nums text-n-slate-10"
            >
              <span class="font-semibold text-n-slate-11">{{
                fmtInt(a.total)
              }}</span>
              <span class="text-n-slate-9">{{ systemBreakdown(a) }}</span>
            </span>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
