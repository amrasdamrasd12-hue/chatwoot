<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useNumberFormatter } from 'shared/composables/useNumberFormatter';

const props = defineProps({
  meta: { type: Object, default: () => ({}) },
});

const { t } = useI18n();
const { formatFullNumber } = useNumberFormatter();

const statsMeta = computed(() => props.meta?.stats || {});

const totalContacts = computed(
  () => statsMeta.value.total_count || statsMeta.value.totalCount || 0
);

const newContacts = computed(
  () =>
    statsMeta.value.new_this_week_count || statsMeta.value.newThisWeekCount || 0
);

const classificationCounts = computed(
  () =>
    statsMeta.value.classification_counts ||
    statsMeta.value.classificationCounts ||
    {}
);

const percentageOfTotal = value => {
  if (!totalContacts.value) return '0%';
  const percentage = (Number(value) / Number(totalContacts.value)) * 100;
  return `${percentage.toFixed(1)}%`;
};

const summaryStats = computed(() => [
  {
    label: t('CONTACTS_LAYOUT.STATS.TOTAL'),
    value: totalContacts.value,
    icon: 'i-lucide-users',
    delta: '100%',
    deltaIcon: 'i-lucide-check',
    deltaClass: 'text-n-violet-11',
    iconClass: 'bg-n-violet-3 text-n-violet-11',
  },
  {
    label: t('CONTACTS_LAYOUT.STATS.NEW_THIS_WEEK'),
    value: newContacts.value,
    icon: 'i-lucide-user-plus',
    delta: percentageOfTotal(newContacts.value),
    deltaIcon: 'i-lucide-trending-up',
    deltaClass: 'text-n-blue-11',
    iconClass: 'bg-n-blue-3 text-n-blue-11',
  },
]);

const classifications = computed(() => {
  const items = [
    {
      key: 'Library',
      label: t(
        'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.LIBRARY'
      ),
      icon: 'i-lucide-library',
      iconClass: 'bg-n-teal-3 text-n-teal-11',
    },
    {
      key: 'Teacher',
      label: t(
        'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.TEACHER'
      ),
      icon: 'i-lucide-graduation-cap',
      iconClass: 'bg-n-blue-3 text-n-blue-11',
    },
    {
      key: 'Student',
      label: t(
        'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.STUDENT'
      ),
      icon: 'i-lucide-user',
      iconClass: 'bg-n-amber-3 text-n-amber-11',
    },
    {
      key: 'Center',
      label: t(
        'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.CENTER'
      ),
      icon: 'i-lucide-building-2',
      iconClass: 'bg-n-purple-3 text-n-purple-11',
    },
    {
      key: 'Other',
      label: t(
        'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.OTHER'
      ),
      icon: 'i-lucide-ellipsis',
      iconClass: 'bg-n-slate-3 text-n-slate-11',
    },
  ];
  return items.map(item => ({
    ...item,
    count: classificationCounts.value[item.key] || 0,
  }));
});
</script>

<template>
  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
    <!-- Summary cards: Total, New This Week -->
    <div
      v-for="stat in summaryStats"
      :key="stat.label"
      class="flex min-h-[6.75rem] items-center justify-between gap-4 rounded-xl border border-n-weak bg-n-solid-1 px-5 py-4 shadow-sm"
    >
      <div class="flex flex-col flex-1 min-w-0 gap-1">
        <div
          class="text-xs font-medium truncate text-n-slate-10 uppercase tracking-wide"
        >
          {{ stat.label }}
        </div>
        <div
          class="text-3xl font-bold leading-tight tabular-nums text-n-slate-12"
        >
          {{ formatFullNumber(stat.value) }}
        </div>
        <div
          class="inline-flex items-center gap-1 text-xs font-semibold tabular-nums"
          :class="stat.deltaClass"
        >
          <span :class="stat.deltaIcon" class="size-3 shrink-0" />
          <span>{{ stat.delta }}</span>
          <span class="font-normal text-n-slate-10">
            {{ $t('CONTACTS_LAYOUT.STATS.OF_TOTAL') }}
          </span>
        </div>
      </div>
      <span
        class="flex items-center justify-center flex-shrink-0 rounded-xl size-12"
        :class="stat.iconClass"
      >
        <span :class="stat.icon" class="size-5" />
      </span>
    </div>

    <!-- Classifications card (spans 2 cols on xl) -->
    <div
      class="xl:col-span-2 flex min-h-[6.75rem] flex-col gap-3 rounded-xl border border-n-weak bg-n-solid-1 px-5 py-4 shadow-sm"
    >
      <div class="text-xs font-medium text-n-slate-10 uppercase tracking-wide">
        {{ t('CONTACTS_LAYOUT.STATS.CLASSIFICATIONS') }}
      </div>
      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3 flex-1">
        <div
          v-for="item in classifications"
          :key="item.key"
          class="flex items-center gap-2.5 min-w-0"
        >
          <span
            class="flex items-center justify-center flex-shrink-0 rounded-lg size-9"
            :class="item.iconClass"
          >
            <span :class="item.icon" class="size-4" />
          </span>
          <div class="flex flex-col min-w-0">
            <span class="text-xs truncate text-n-slate-10">{{
              item.label
            }}</span>
            <span
              class="text-lg font-bold leading-tight tabular-nums text-n-slate-12"
            >
              {{ formatFullNumber(item.count) }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
