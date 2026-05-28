<script setup>
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  modelValue: {
    type: String,
    default: 'table',
    validator: value => ['table', 'card'].includes(value),
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const views = [
  {
    value: 'table',
    icon: 'i-lucide-table-2',
    label: t('CONTACTS_LAYOUT.HEADER.VIEW_TOGGLE.TABLE'),
  },
  {
    value: 'card',
    icon: 'i-lucide-rows-3',
    label: t('CONTACTS_LAYOUT.HEADER.VIEW_TOGGLE.CARD'),
  },
];
</script>

<template>
  <div
    class="inline-flex items-center flex-shrink-0 h-9 gap-1 p-0.5 rounded-lg bg-n-alpha-2"
  >
    <Button
      v-for="view in views"
      :key="view.value"
      v-tooltip.bottom="view.label"
      :icon="view.icon"
      :aria-label="view.label"
      size="sm"
      color="slate"
      :variant="modelValue === view.value ? 'solid' : 'ghost'"
      class="!size-8"
      @click="emit('update:modelValue', view.value)"
    />
  </div>
</template>
