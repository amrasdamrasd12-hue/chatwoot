<script setup>
import {
  ref,
  computed,
  onMounted,
  nextTick,
  onUnmounted,
  useTemplateRef,
  inject,
} from 'vue';
import { useWindowSize, useElementBounding, useScrollLock } from '@vueuse/core';

import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

const props = defineProps({
  x: { type: Number, default: 0 },
  y: { type: Number, default: 0 },
});

const emit = defineEmits(['close']);

const elementToLock = inject('contextMenuElementTarget', null);

const menuRef = useTemplateRef('menuRef');

const scrollLockElement = computed(() => {
  if (!elementToLock?.value) return null;
  return elementToLock.value?.$el;
});

const isLocked = useScrollLock(scrollLockElement);

const { width: windowWidth, height: windowHeight } = useWindowSize();
const { width: menuWidth, height: menuHeight } = useElementBounding(menuRef);

const calculatePosition = (x, y, menuW, menuH, windowW, windowH) => {
  const PADDING = 16;
  // Initial position
  let left = x;
  let top = y;
  // Boundary checks
  const isOverflowingRight = left + menuW > windowW - PADDING;
  const isOverflowingBottom = top + menuH > windowH - PADDING;
  // Adjust position if overflowing
  if (isOverflowingRight) left = windowW - menuW - PADDING;
  if (isOverflowingBottom) top = windowH - menuH - PADDING;
  return {
    left: Math.max(PADDING, left),
    top: Math.max(PADDING, top),
  };
};

const position = computed(() => {
  if (!menuRef.value) return { top: `${props.y}px`, left: `${props.x}px` };

  const { left, top } = calculatePosition(
    props.x,
    props.y,
    menuWidth.value,
    menuHeight.value,
    windowWidth.value,
    windowHeight.value
  );

  return {
    top: `${top}px`,
    left: `${left}px`,
  };
});

// When the menu is opened via right-click (contextmenu), the browser can pull
// focus back right after the menu mounts, firing a premature blur that would
// close the menu before it ever paints. Ignore blur until the menu has settled.
const isReady = ref(false);

onMounted(() => {
  isLocked.value = true;
  nextTick(() => {
    menuRef.value?.focus();
    setTimeout(() => {
      isReady.value = true;
    }, 100);
  });
});

const handleClose = () => {
  isLocked.value = false;
  emit('close');
};

const handleBlur = () => {
  if (!isReady.value) {
    menuRef.value?.focus();
    return;
  }
  handleClose();
};

onUnmounted(() => {
  isLocked.value = false;
});
</script>

<template>
  <TeleportWithDirection to="body">
    <div
      ref="menuRef"
      class="fixed outline-none z-[9999] cursor-pointer"
      :style="position"
      tabindex="0"
      @blur="handleBlur"
    >
      <slot />
    </div>
  </TeleportWithDirection>
</template>
