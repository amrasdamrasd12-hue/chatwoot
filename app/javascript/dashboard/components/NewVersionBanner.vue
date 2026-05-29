<script setup>
import { ref, watch, onBeforeUnmount } from 'vue';
import { useBuildVersionWatcher } from 'dashboard/composables/useBuildVersionWatcher';

// Eltafouk: deploy-detection banner. Sits at the very top of the
// dashboard so agents can't miss the update. Idle-aware auto-reload:
// if the agent stops typing for 30 s we silently refresh; otherwise we
// hard-refresh after 10 min regardless so the tab can't outlive the
// bundle.
//
// Test deploy 2026-05-29 — verify auto-reload reaches Noha's live tab.
const IDLE_RELOAD_AFTER_MS = 30 * 1000;
const FORCE_RELOAD_AFTER_MS = 10 * 60 * 1000;
const TICK_MS = 5_000;

const L = {
  TITLE: 'تم نشر تحديث جديد',
  BODY: 'سيتم إعادة تحميل الصفحة تلقائياً خلال لحظات. اضغط للتحديث الآن.',
  RELOAD: 'إعادة تحميل الآن',
};

const { newVersionAvailable, lastActivityAt } = useBuildVersionWatcher();
const visible = ref(false);
let firstDetectedAt = null;
let tickHandle = null;

const reload = () => {
  // Bypass the disk cache so the new bundle is fetched fresh — Safari
  // is the loud edge case here, it'll happily serve the stale JS even
  // after the manifest hash changed.
  window.location.reload(true);
};

watch(newVersionAvailable, isNew => {
  if (!isNew || visible.value) return;
  visible.value = true;
  firstDetectedAt = Date.now();

  // Reload as soon as the agent is idle for IDLE_RELOAD_AFTER_MS, and
  // unconditionally after FORCE_RELOAD_AFTER_MS. Two checks per tick so
  // a quick lull during typing still triggers the silent reload.
  tickHandle = setInterval(() => {
    const idleFor = Date.now() - lastActivityAt.value;
    const elapsed = Date.now() - firstDetectedAt;
    if (idleFor >= IDLE_RELOAD_AFTER_MS || elapsed >= FORCE_RELOAD_AFTER_MS) {
      clearInterval(tickHandle);
      reload();
    }
  }, TICK_MS);
});

onBeforeUnmount(() => {
  if (tickHandle) clearInterval(tickHandle);
});
</script>

<template>
  <Transition
    enter-active-class="transition-all duration-300 ease-out"
    enter-from-class="-translate-y-full opacity-0"
    enter-to-class="translate-y-0 opacity-100"
  >
    <button
      v-if="visible"
      type="button"
      class="fixed inset-x-0 top-0 z-[9999] flex items-center justify-center gap-3 bg-gradient-to-b from-n-brand to-n-blue-10 px-4 py-2.5 text-[13px] font-medium text-white shadow-md transition-colors hover:brightness-110"
      @click="reload"
    >
      <span class="i-lucide-refresh-cw size-3.5 animate-spin-slow" />
      <span class="font-semibold">{{ L.TITLE }}</span>
      <span class="hidden text-white/90 sm:inline">{{ L.BODY }}</span>
      <span
        class="rounded-md bg-white/15 px-2 py-0.5 text-[11.5px] font-semibold ring-1 ring-white/30"
      >
        {{ L.RELOAD }}
      </span>
    </button>
  </Transition>
</template>

<style scoped>
@keyframes spin-slow {
  to {
    transform: rotate(360deg);
  }
}
.animate-spin-slow {
  animation: spin-slow 3s linear infinite;
}
</style>
