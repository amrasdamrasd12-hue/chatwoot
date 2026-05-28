<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  activeSort: { type: String, default: 'last_activity_at' },
  activeOrdering: { type: String, default: '' },
  allSelected: { type: Boolean, default: false },
  isIndeterminate: { type: Boolean, default: false },
});

const emit = defineEmits(['update:sort', 'toggleAll']);

const { t } = useI18n();

const columns = [
  {
    key: 'name',
    label: t('CONTACTS_LAYOUT.TABLE.COLUMNS.NAME'),
    class: 'ltr:pl-[3.5rem] rtl:pr-[3.5rem]',
    alignClass: 'justify-start',
    sortable: true,
  },
  {
    key: 'phone',
    label: t('CONTACTS_LAYOUT.TABLE.COLUMNS.PHONE'),
    class: 'text-center',
    alignClass: 'justify-center',
    sortable: false,
  },
  {
    key: 'classification',
    label: t('CONTACTS_LAYOUT.TABLE.COLUMNS.CLASSIFICATION'),
    class: 'text-center',
    alignClass: 'justify-center',
    sortable: false,
  },
  {
    key: 'governorate',
    label: t('CONTACTS_LAYOUT.TABLE.COLUMNS.GOVERNORATE'),
    class: 'text-center',
    alignClass: 'justify-center',
    sortable: false,
  },
  {
    key: 'district',
    label: t('CONTACTS_LAYOUT.TABLE.COLUMNS.DISTRICT'),
    class: 'text-center',
    alignClass: 'justify-center',
    sortable: false,
  },
  {
    key: 'created_at',
    label: t('CONTACTS_LAYOUT.TABLE.COLUMNS.CREATED_AT'),
    class: '',
    alignClass: 'justify-start',
    sortable: true,
  },
];

const nextOrdering = key => {
  if (props.activeSort !== key) return '';
  return props.activeOrdering === '-' ? '' : '-';
};

const sortIcon = key => {
  if (props.activeSort !== key) return 'i-lucide-arrow-up-down';
  return props.activeOrdering === '-'
    ? 'i-lucide-arrow-down'
    : 'i-lucide-arrow-up';
};

const headerCheckboxModel = computed({
  get: () => props.allSelected,
  set: value => emit('toggleAll', value),
});

const updateSort = column => {
  if (!column.sortable) return;
  emit('update:sort', { sort: column.key, order: nextOrdering(column.key) });
};
</script>

<template>
  <thead class="sticky top-0 z-[1] bg-n-alpha-2 dark:bg-n-solid-2">
    <tr class="border-b border-n-weak">
      <th class="h-11 px-3 py-2 text-center">
        <div class="flex items-center justify-center">
          <Checkbox
            v-model="headerCheckboxModel"
            :indeterminate="isIndeterminate"
          />
        </div>
      </th>
      <th
        v-for="column in columns"
        :key="column.key"
        class="h-11 px-3 py-2 text-sm font-bold text-start text-n-slate-12"
        :class="column.class"
      >
        <button
          v-if="column.sortable"
          type="button"
          class="inline-flex w-full max-w-full items-center gap-1.5 transition-colors text-n-slate-12 hover:text-n-brand"
          :class="column.alignClass"
          @click="updateSort(column)"
        >
          <span class="min-w-0 truncate">{{ column.label }}</span>
          <span
            :class="sortIcon(column.key)"
            class="size-3.5 shrink-0 opacity-70"
          />
        </button>
        <span
          v-else
          class="inline-flex w-full max-w-full items-center text-n-slate-12"
          :class="column.alignClass"
        >
          {{ column.label }}
        </span>
      </th>
    </tr>
  </thead>
</template>
