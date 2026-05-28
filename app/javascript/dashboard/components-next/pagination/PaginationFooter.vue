<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useNumberFormatter } from 'shared/composables/useNumberFormatter';

const props = defineProps({
  currentPage: { type: Number, required: true },
  totalItems: { type: Number, required: true },
  itemsPerPage: { type: Number, default: 15 },
  currentPageInfo: { type: String, default: '' },
  perPageOptions: {
    type: Array,
    default: () => [15, 25, 50, 100, 250, 500, 1000],
  },
});

const emit = defineEmits(['update:currentPage', 'update:itemsPerPage']);
const { t } = useI18n();
const { formatCompactNumber, formatFullNumber } = useNumberFormatter();

const totalPages = computed(() =>
  Math.ceil(props.totalItems / props.itemsPerPage)
);
const startItem = computed(
  () => (props.currentPage - 1) * props.itemsPerPage + 1
);
const endItem = computed(() =>
  Math.min(startItem.value + props.itemsPerPage - 1, props.totalItems)
);
const isFirstPage = computed(() => props.currentPage === 1);
const isLastPage = computed(() => props.currentPage === totalPages.value);

const changePage = newPage => {
  if (newPage >= 1 && newPage <= totalPages.value) {
    emit('update:currentPage', newPage);
  }
};

const changePerPage = event => {
  const newPerPage = Number(event.target.value);
  if (newPerPage !== props.itemsPerPage) {
    emit('update:itemsPerPage', newPerPage);
  }
};

const currentPageInformation = computed(() => {
  const translationKey = props.currentPageInfo || 'PAGINATION_FOOTER.SHOWING';
  return t(
    translationKey,
    {
      startItem: formatFullNumber(startItem.value),
      endItem: formatFullNumber(endItem.value),
      totalItems: formatCompactNumber(props.totalItems),
    },
    Number(props.totalItems)
  );
});

const visiblePageNumbers = computed(() => {
  const pages = [];
  const lastPage = totalPages.value;
  const start = Math.max(1, props.currentPage - 1);
  const end = Math.min(lastPage, start + 2);
  for (let page = start; page <= end; page += 1) {
    pages.push(page);
  }
  return pages;
});

const showFirstPageButton = computed(
  () => totalPages.value > 3 && !visiblePageNumbers.value.includes(1)
);

const showLastPageButton = computed(
  () =>
    totalPages.value > 3 && !visiblePageNumbers.value.includes(totalPages.value)
);
</script>

<template>
  <div
    class="flex items-center justify-between w-full h-11 px-3 border bg-n-solid-1 border-n-weak rounded-xl"
  >
    <!-- Page info -->
    <span
      class="min-w-0 text-xs text-n-slate-10 truncate tabular-nums shrink-0"
    >
      {{ currentPageInformation }}
    </span>

    <!-- Page buttons -->
    <div class="flex items-center gap-0.5">
      <button
        class="inline-flex items-center justify-center size-7 rounded-md text-n-slate-10 transition-colors hover:bg-n-alpha-2 hover:text-n-slate-12 disabled:opacity-30 disabled:pointer-events-none"
        :disabled="isFirstPage"
        @click="changePage(currentPage - 1)"
      >
        <span class="i-lucide-chevron-right size-3.5" />
      </button>

      <template v-if="showFirstPageButton">
        <button
          class="inline-flex items-center justify-center size-7 rounded-md text-xs font-medium tabular-nums text-n-slate-11 transition-colors hover:bg-n-alpha-2 hover:text-n-slate-12"
          @click="changePage(1)"
        >
          {{ formatFullNumber(1) }}
        </button>
        <span
          class="inline-flex items-center justify-center size-7 text-xs text-n-slate-8 select-none"
        >
          ···
        </span>
      </template>

      <button
        v-for="page in visiblePageNumbers"
        :key="page"
        class="inline-flex items-center justify-center size-7 rounded-md text-xs font-medium tabular-nums transition-colors"
        :class="
          page === currentPage
            ? 'bg-n-brand text-white shadow-sm'
            : 'text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
        "
        @click="changePage(page)"
      >
        {{ formatFullNumber(page) }}
      </button>

      <template v-if="showLastPageButton">
        <span
          class="inline-flex items-center justify-center size-7 text-xs text-n-slate-8 select-none"
        >
          ···
        </span>
        <button
          class="inline-flex items-center justify-center size-7 rounded-md text-xs font-medium tabular-nums text-n-slate-11 transition-colors hover:bg-n-alpha-2 hover:text-n-slate-12"
          @click="changePage(totalPages)"
        >
          {{ formatFullNumber(totalPages) }}
        </button>
      </template>

      <button
        class="inline-flex items-center justify-center size-7 rounded-md text-n-slate-10 transition-colors hover:bg-n-alpha-2 hover:text-n-slate-12 disabled:opacity-30 disabled:pointer-events-none"
        :disabled="isLastPage"
        @click="changePage(currentPage + 1)"
      >
        <span class="i-lucide-chevron-left size-3.5" />
      </button>
    </div>

    <!-- Per page selector -->
    <div class="flex items-center gap-1.5 shrink-0">
      <span class="text-xs text-n-slate-10 whitespace-nowrap">
        {{ t('PAGINATION_FOOTER.PER_PAGE') }}
      </span>
      <div
        class="relative inline-flex items-center h-7 rounded-md border border-n-weak bg-n-alpha-1 cursor-pointer overflow-hidden"
      >
        <span
          class="ps-2.5 pe-5 text-xs font-medium text-n-slate-12 tabular-nums pointer-events-none"
        >
          {{ formatFullNumber(itemsPerPage) }}
        </span>
        <span
          class="absolute top-1/2 -translate-y-1/2 end-1.5 i-lucide-chevron-down size-2.5 text-n-slate-9 pointer-events-none"
        />
        <select
          class="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
          :value="itemsPerPage"
          @change="changePerPage"
        >
          <option
            v-for="option in perPageOptions"
            :key="option"
            :value="option"
          >
            {{ formatFullNumber(option) }}
          </option>
        </select>
      </div>
    </div>
  </div>
</template>
