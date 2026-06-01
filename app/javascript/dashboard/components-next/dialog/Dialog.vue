<script setup>
import { ref, computed, provide, nextTick, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

const props = defineProps({
  type: {
    type: String,
    default: 'edit',
    validator: value => ['alert', 'edit'].includes(value),
  },
  title: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
  cancelButtonLabel: {
    type: String,
    default: '',
  },
  confirmButtonLabel: {
    type: String,
    default: '',
  },
  disableConfirmButton: {
    type: Boolean,
    default: false,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  showCancelButton: {
    type: Boolean,
    default: true,
  },
  showConfirmButton: {
    type: Boolean,
    default: true,
  },
  overflowYAuto: {
    type: Boolean,
    default: false,
  },
  stickyFooter: {
    type: Boolean,
    default: false,
  },
  width: {
    type: String,
    default: 'lg',
    validator: value =>
      [
        '7xl',
        '6xl',
        '5xl',
        '4xl',
        '3xl',
        '2xl',
        'xl',
        'lg',
        'md',
        'sm',
      ].includes(value),
  },
  position: {
    type: String,
    default: 'center',
    validator: value => ['center', 'top'].includes(value),
  },
  closeOnBackdropClick: {
    type: Boolean,
    default: true,
  },
  ariaLabelledById: {
    type: String,
    default: '',
  },
  ariaDescribedById: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['confirm', 'close']);

const { t } = useI18n();

const dialogRef = ref(null);
const dialogContentRef = ref(null);
const isOpen = ref(false);
const previousFocusedElement = ref(null);

const maxWidthClass = computed(() => {
  const classesMap = {
    '7xl': 'max-w-7xl',
    '6xl': 'max-w-6xl',
    '5xl': 'max-w-5xl',
    '4xl': 'max-w-4xl',
    '3xl': 'max-w-3xl',
    '2xl': 'max-w-2xl',
    xl: 'max-w-xl',
    lg: 'max-w-lg',
    md: 'max-w-md',
    sm: 'max-w-sm',
  };

  return classesMap[props.width] ?? 'max-w-md';
});

const positionClass = computed(() =>
  props.position === 'top' ? 'dialog-position-top' : ''
);

const open = async () => {
  if (isOpen.value) return;

  previousFocusedElement.value = document.activeElement;
  isOpen.value = true;
  document.documentElement.style.overflow = 'hidden';

  dialogRef.value?.showModal();
  await nextTick();

  // Focus the dialog's form for keyboard navigation
  dialogContentRef.value?.focus();
};

const close = () => {
  if (!isOpen.value) return;

  isOpen.value = false;
  dialogRef.value?.close();
  document.documentElement.style.overflow = '';

  // Restore focus to the element that triggered the dialog
  nextTick(() => {
    previousFocusedElement.value?.focus?.();
  });

  emit('close');
};

const handleNativeClose = () => {
  if (!isOpen.value) return;

  isOpen.value = false;
  document.documentElement.style.overflow = '';
  nextTick(() => {
    previousFocusedElement.value?.focus?.();
  });
  emit('close');
};

const confirm = () => {
  emit('confirm');
};

const handleBackdropClick = e => {
  if (e.target === dialogRef.value && props.closeOnBackdropClick) close();
};

onBeforeUnmount(() => {
  if (isOpen.value) {
    document.documentElement.style.overflow = '';
  }
});

provide('dialogRef', dialogRef);

// Expose isOpen as a getter so callers can distinguish "props say show=true
// but dialog hasn't opened yet" from "dialog is actually visible". This
// lets SpellCheckModal's global keydown listener guard against the race
// where the parent sets show=true synchronously but the async watcher
// hasn't called open() yet — without this, the same Enter keypress that
// triggers confirmOnSendReply() also fires onSendCorrected() before the
// modal is visible.
defineExpose({ open, close, getIsOpen: () => isOpen.value });
</script>

<template>
  <TeleportWithDirection to="body">
    <dialog
      ref="dialogRef"
      class="w-full transition-all duration-300 ease-in-out shadow-xl rounded-xl"
      :class="[
        maxWidthClass,
        positionClass,
        overflowYAuto && !stickyFooter
          ? 'overflow-y-auto max-h-[90vh]'
          : 'overflow-visible',
      ]"
      :aria-labelledby="ariaLabelledById"
      :aria-describedby="ariaDescribedById"
      @close="handleNativeClose"
      @click="handleBackdropClick"
    >
      <form
        ref="dialogContentRef"
        class="relative flex flex-col w-full text-start align-middle transition-all duration-300 ease-in-out transform bg-n-alpha-3 backdrop-blur-[100px] shadow-xl rounded-xl"
        :class="
          overflowYAuto && stickyFooter
            ? 'max-h-[90vh] overflow-hidden'
            : 'h-auto gap-6 p-6 overflow-visible'
        "
        @submit.prevent="confirm"
        @click.stop
      >
        <!-- Sticky-footer layout: content scrolls, footer stays pinned -->
        <template v-if="overflowYAuto && stickyFooter">
          <div class="flex-1 min-h-0 overflow-y-auto flex flex-col gap-6 p-6">
            <div v-if="title || description" class="flex flex-col gap-2">
              <h3
                id="dialog-title"
                class="text-base font-medium leading-6 text-n-slate-12"
              >
                {{ title }}
              </h3>
              <slot name="description">
                <p
                  v-if="description"
                  id="dialog-description"
                  class="mb-0 text-sm text-n-slate-11"
                >
                  {{ description }}
                </p>
              </slot>
            </div>
            <slot v-if="isOpen" />
          </div>
          <div class="shrink-0 px-6 pb-6 pt-4 border-t border-n-weak">
            <slot name="footer">
              <div
                v-if="showCancelButton || showConfirmButton"
                class="flex items-center justify-between w-full gap-3"
              >
                <Button
                  v-if="showCancelButton"
                  variant="faded"
                  color="slate"
                  :label="cancelButtonLabel || t('DIALOG.BUTTONS.CANCEL')"
                  class="w-full"
                  type="button"
                  @click="close"
                />
                <Button
                  v-if="showConfirmButton"
                  :color="type === 'edit' ? 'blue' : 'ruby'"
                  :label="confirmButtonLabel || t('DIALOG.BUTTONS.CONFIRM')"
                  class="w-full"
                  :is-loading="isLoading"
                  :disabled="disableConfirmButton || isLoading"
                  type="submit"
                />
              </div>
            </slot>
          </div>
        </template>

        <!-- Normal layout -->
        <template v-else>
          <div v-if="title || description" class="flex flex-col gap-2">
            <h3
              id="dialog-title"
              class="text-base font-medium leading-6 text-n-slate-12"
            >
              {{ title }}
            </h3>
            <slot name="description">
              <p
                v-if="description"
                id="dialog-description"
                class="mb-0 text-sm text-n-slate-11"
              >
                {{ description }}
              </p>
            </slot>
          </div>
          <slot v-if="isOpen" />
          <slot name="footer">
            <div
              v-if="showCancelButton || showConfirmButton"
              class="flex items-center justify-between w-full gap-3"
            >
              <Button
                v-if="showCancelButton"
                variant="faded"
                color="slate"
                :label="cancelButtonLabel || t('DIALOG.BUTTONS.CANCEL')"
                class="w-full"
                type="button"
                @click="close"
              />
              <Button
                v-if="showConfirmButton"
                :color="type === 'edit' ? 'blue' : 'ruby'"
                :label="confirmButtonLabel || t('DIALOG.BUTTONS.CONFIRM')"
                class="w-full"
                :is-loading="isLoading"
                :disabled="disableConfirmButton || isLoading"
                type="submit"
              />
            </div>
          </slot>
        </template>
      </form>
    </dialog>
  </TeleportWithDirection>
</template>

<style scoped>
dialog::backdrop {
  @apply bg-n-alpha-black1 backdrop-blur-[4px];
}

.dialog-position-top {
  margin-top: clamp(2rem, 5vh, 5rem);
  margin-bottom: auto;
}
</style>
