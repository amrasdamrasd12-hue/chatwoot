<script setup>
import Icon from 'next/icon/Icon.vue';
import { computed } from 'vue';

const props = defineProps({
  label: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: '',
  },
  count: {
    type: Number,
    default: 0,
  },
});

const countLabel = computed(() => (props.count > 99 ? '99+' : props.count));
</script>

<template>
  <div class="px-2 pt-3 pb-1 select-none pointer-events-none">
    <div
      class="flex items-center gap-1.5 text-n-slate-9 border-t border-n-slate-4/60 pt-2"
    >
      <Icon v-if="icon" :icon="icon" class="size-3 opacity-70" />
      <span
        class="text-[10px] font-semibold leading-none flex-grow min-w-0 truncate tracking-[0.08em] uppercase"
      >
        {{ label }}
      </span>
      <span
        v-if="count"
        dir="ltr"
        class="inline-flex h-[16px] min-w-[16px] flex-shrink-0 items-center justify-center rounded bg-n-ruby-9/15 px-1 text-[10px] font-semibold leading-none text-n-ruby-11 tabular-nums"
      >
        {{ countLabel }}
      </span>
    </div>
  </div>
</template>
