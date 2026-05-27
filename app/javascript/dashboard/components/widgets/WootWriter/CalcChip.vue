<script setup>
defineProps({
  result: { type: String, required: true },
});
const emit = defineEmits(['accept', 'dismiss']);
</script>

<template>
  <div
    class="flex items-center gap-2 px-3 py-1.5 bg-n-alpha-2 border border-n-weak rounded-lg w-fit text-sm"
  >
    <span class="text-n-slate-11 font-mono select-none">
      {{ $t('CALC_CHIP.EQUALS_PREFIX') }}{{ result }}
    </span>
    <button
      class="flex items-center gap-1 px-2 py-0.5 rounded bg-woot-500 hover:bg-woot-600 text-white text-xs font-medium transition-colors"
      @click="emit('accept')"
    >
      <fluent-icon icon="checkmark" size="12" />
      {{ $t('CALC_CHIP.ACCEPT') }}
    </button>
    <button
      class="text-n-slate-11 hover:text-n-slate-12 transition-colors"
      @click="emit('dismiss')"
    >
      <fluent-icon icon="dismiss" size="12" />
    </button>
  </div>
</template>
