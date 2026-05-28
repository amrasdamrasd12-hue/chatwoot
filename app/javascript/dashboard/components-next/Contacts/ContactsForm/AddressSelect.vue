<script setup>
import { ref, computed, watch, inject, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  options: { type: Array, required: true },
  modelValue: { type: String, default: '' },
  placeholder: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue', 'change']);

const { t } = useI18n();

const parentDialogRef = inject('dialogRef', null);
const teleportTarget = computed(() => parentDialogRef?.value ?? document.body);

const open = ref(false);
const search = ref('');
const triggerRef = ref(null);
const searchRef = ref(null);
const dropStyle = ref({});

const selectedLabel = computed(() => {
  const found = props.options.find(o => o.value === props.modelValue);
  return found ? found.label : props.placeholder;
});

const isPlaceholder = computed(() => !props.modelValue);

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase();
  if (!q) return props.options;
  return props.options.filter(o => o.label.toLowerCase().includes(q));
});

const updatePosition = () => {
  const rect = triggerRef.value?.getBoundingClientRect();
  if (!rect) return;
  dropStyle.value = {
    position: 'fixed',
    top: `${rect.bottom + 2}px`,
    left: `${rect.left}px`,
    width: `${Math.max(rect.width, 200)}px`,
    zIndex: 9999,
  };
};

const openDropdown = () => {
  search.value = '';
  updatePosition();
  open.value = true;
  setTimeout(() => searchRef.value?.focus(), 30);
};

const closeDropdown = () => {
  open.value = false;
};

const select = opt => {
  emit('update:modelValue', opt.value);
  emit('change');
  closeDropdown();
};

const handleDocClick = e => {
  if (!triggerRef.value?.contains(e.target)) closeDropdown();
};

watch(open, val => {
  if (val) document.addEventListener('click', handleDocClick, true);
  else document.removeEventListener('click', handleDocClick, true);
});

onBeforeUnmount(() => {
  document.removeEventListener('click', handleDocClick, true);
});
</script>

<template>
  <div ref="triggerRef" class="relative w-full">
    <button
      type="button"
      class="flex items-center justify-between w-full h-7 px-2 rounded-lg border border-n-weak bg-n-alpha-black2 text-xs focus:outline-none focus:border-n-brand"
      :class="isPlaceholder ? 'text-n-slate-9' : 'text-n-slate-12'"
      @click.stop="open ? closeDropdown() : openDropdown()"
    >
      <span class="truncate">{{ selectedLabel }}</span>
      <span
        class="flex-shrink-0 ml-1 size-3"
        :class="open ? 'i-ph-caret-up' : 'i-ph-caret-down'"
      />
    </button>

    <Teleport :to="teleportTarget">
      <div
        v-if="open"
        :style="dropStyle"
        class="rounded-lg border border-n-strong bg-n-solid-1 shadow-lg overflow-hidden"
      >
        <div class="relative border-b border-n-strong">
          <span
            class="absolute left-2 top-1/2 -translate-y-1/2 i-lucide-search size-3 text-n-slate-10"
          />
          <input
            ref="searchRef"
            v-model="search"
            type="search"
            class="reset-base w-full py-1.5 pl-7 pr-2 text-xs focus:outline-none bg-transparent text-n-slate-12"
            @click.stop
          />
        </div>
        <ul class="max-h-48 overflow-y-auto py-1 mb-0">
          <li
            v-for="opt in filtered"
            :key="opt.value"
            class="px-3 py-1.5 text-xs cursor-pointer hover:bg-n-alpha-2 text-n-slate-12 flex items-center justify-between"
            :class="{ 'bg-n-alpha-2 font-medium': opt.value === modelValue }"
            @click.stop="select(opt)"
          >
            {{ opt.label }}
            <span
              v-if="opt.value === modelValue"
              class="i-lucide-check size-3 text-n-slate-11"
            />
          </li>
          <li
            v-if="filtered.length === 0"
            class="px-3 py-2 text-xs text-n-slate-10"
          >
            {{
              t(
                'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ADDRESS_TABLE.NO_RESULTS'
              )
            }}
          </li>
        </ul>
      </div>
    </Teleport>
  </div>
</template>
