<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const filters = [
  {
    value: 'active',
    label: t('CONTACTS_LAYOUT.QUICK_FILTERS.ACTIVE'),
    icon: 'i-lucide-radio',
  },
  {
    value: 'new',
    label: t('CONTACTS_LAYOUT.QUICK_FILTERS.NEW'),
    icon: 'i-lucide-sparkles',
  },
  {
    value: 'has_email',
    label: t('CONTACTS_LAYOUT.QUICK_FILTERS.HAS_EMAIL'),
    icon: 'i-lucide-mail',
  },
  {
    value: 'has_phone',
    label: t('CONTACTS_LAYOUT.QUICK_FILTERS.HAS_PHONE'),
    icon: 'i-lucide-phone',
  },
];

const activeFilter = computed({
  get: () => props.modelValue,
  set: value => emit('update:modelValue', value),
});

const toggleFilter = value => {
  activeFilter.value = activeFilter.value === value ? '' : value;
};
</script>

<template>
  <div
    class="flex flex-wrap items-center justify-end gap-2 p-3 border shadow-sm rounded-xl bg-n-solid-1 border-n-weak"
  >
    <div class="flex flex-wrap items-center justify-end gap-2">
      <Button
        v-for="filter in filters"
        :key="filter.value"
        :label="filter.label"
        :icon="filter.icon"
        size="sm"
        color="slate"
        :variant="activeFilter === filter.value ? 'solid' : 'outline'"
        class="!h-9"
        @click="toggleFilter(filter.value)"
      />
      <Button
        v-if="activeFilter"
        :label="t('CONTACTS_LAYOUT.QUICK_FILTERS.CLEAR')"
        icon="i-lucide-x"
        size="sm"
        color="slate"
        variant="ghost"
        class="!h-9"
        @click="activeFilter = ''"
      />
    </div>
  </div>
</template>
