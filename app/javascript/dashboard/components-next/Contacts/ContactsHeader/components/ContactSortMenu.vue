<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

const props = defineProps({
  activeSort: {
    type: String,
    default: 'last_activity_at',
  },
  activeOrdering: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['update:sort']);

const { t } = useI18n();

const isMenuOpen = ref(false);

const sortMenus = computed(() => [
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.SORT_BY.OPTIONS.NAME'),
    value: 'name',
  },
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.SORT_BY.OPTIONS.EMAIL'),
    value: 'email',
  },
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.SORT_BY.OPTIONS.COMPANY'),
    value: 'company_name',
  },
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.SORT_BY.OPTIONS.COUNTRY'),
    value: 'country',
  },
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.SORT_BY.OPTIONS.CITY'),
    value: 'city',
  },
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.SORT_BY.OPTIONS.LAST_ACTIVITY'),
    value: 'last_activity_at',
  },
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.SORT_BY.OPTIONS.CREATED_AT'),
    value: 'created_at',
  },
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.SORT_BY.OPTIONS.UPDATED_AT'),
    value: 'updated_at',
  },
]);

const orderingMenus = computed(() => [
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.ORDER.OPTIONS.ASCENDING'),
    value: '',
  },
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.ORDER.OPTIONS.DESCENDING'),
    value: '-',
  },
]);

const activeSortLabel = computed(() => {
  const selectedMenu = sortMenus.value.find(
    menu => menu.value === props.activeSort
  );
  return (
    selectedMenu?.label || t('CONTACTS_LAYOUT.HEADER.ACTIONS.SORT_BY.LABEL')
  );
});

const activeOrderingLabel = computed(() => {
  const selectedMenu = orderingMenus.value.find(
    menu => menu.value === props.activeOrdering
  );
  return selectedMenu?.label || t('CONTACTS_LAYOUT.HEADER.ACTIONS.ORDER.LABEL');
});

const DATE_SORT_FIELDS = ['created_at', 'last_activity_at', 'updated_at'];

const handleSortChange = value => {
  const order = DATE_SORT_FIELDS.includes(value) ? '-' : props.activeOrdering;
  emit('update:sort', { sort: value, order });
};

const handleOrderChange = value => {
  emit('update:sort', { sort: props.activeSort, order: value });
};
</script>

<template>
  <div class="relative">
    <Button
      icon="i-lucide-arrow-down-up"
      color="slate"
      size="sm"
      variant="ghost"
      :class="isMenuOpen ? 'bg-n-alpha-2' : ''"
      @click="isMenuOpen = !isMenuOpen"
    />
    <div
      v-if="isMenuOpen"
      v-on-clickaway="() => (isMenuOpen = false)"
      class="absolute top-full mt-1 ltr:-right-32 rtl:-left-32 sm:ltr:right-0 sm:rtl:left-0 flex flex-col gap-4 bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak w-72 rounded-xl p-4"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-n-slate-12">
          {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.SORT_BY.LABEL') }}
        </span>
        <SelectMenu
          :model-value="activeSort"
          :options="sortMenus"
          :label="activeSortLabel"
          @update:model-value="handleSortChange"
        />
      </div>
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-n-slate-12">
          {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.ORDER.LABEL') }}
        </span>
        <SelectMenu
          :model-value="activeOrdering"
          :options="orderingMenus"
          :label="activeOrderingLabel"
          @update:model-value="handleOrderChange"
        />
      </div>
    </div>
  </div>
</template>
