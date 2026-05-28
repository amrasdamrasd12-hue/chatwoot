<script setup>
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';

import ContactListHeaderWrapper from 'dashboard/components-next/Contacts/ContactsHeader/ContactListHeaderWrapper.vue';
import ContactsActiveFiltersPreview from 'dashboard/components-next/Contacts/ContactsHeader/components/ContactsActiveFiltersPreview.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import ContactsLoadMore from 'dashboard/components-next/Contacts/ContactsLoadMore.vue';

const props = defineProps({
  searchValue: { type: String, default: '' },
  headerTitle: { type: String, default: '' },
  showPaginationFooter: { type: Boolean, default: true },
  currentPage: { type: Number, default: 1 },
  totalItems: { type: Number, default: 100 },
  itemsPerPage: { type: Number, default: 15 },
  perPageOptions: {
    type: Array,
    default: () => [15, 25, 50, 100, 250, 500, 1000],
  },
  activeSort: { type: String, default: '' },
  activeOrdering: { type: String, default: '' },
  activeSegment: { type: Object, default: null },
  segmentsId: { type: [String, Number], default: 0 },
  hasAppliedFilters: { type: Boolean, default: false },
  isFetchingList: { type: Boolean, default: false },
  useInfiniteScroll: { type: Boolean, default: false },
  hasMore: { type: Boolean, default: false },
  isLoadingMore: { type: Boolean, default: false },
  viewMode: { type: String, default: 'table' },
  showViewToggle: { type: Boolean, default: true },
  selectedContactIds: { type: Array, default: () => [] },
});

const emit = defineEmits([
  'update:currentPage',
  'update:itemsPerPage',
  'update:sort',
  'search',
  'applyFilter',
  'clearFilters',
  'loadMore',
  'update:viewMode',
  'contactCreated',
]);

const route = useRoute();

const contactListHeaderWrapper = ref(null);

const isNotSegmentView = computed(() => {
  return route.name !== 'contacts_dashboard_segments_index';
});

const isActiveView = computed(() => {
  return route.name === 'contacts_dashboard_active';
});

const isLabelView = computed(
  () => route.name === 'contacts_dashboard_labels_index'
);

const showActiveFiltersPreview = computed(() => {
  return (
    (props.hasAppliedFilters || !isNotSegmentView.value) &&
    !props.isFetchingList &&
    !isLabelView.value &&
    !isActiveView.value
  );
});

const updateCurrentPage = page => {
  emit('update:currentPage', page);
};

const openFilter = () => {
  contactListHeaderWrapper.value?.onToggleFilters();
};

const openContactExportDialog = () => {
  contactListHeaderWrapper.value?.openContactExportDialog();
};

const showLoadMore = computed(() => {
  return props.useInfiniteScroll && props.hasMore;
});

const showPagination = computed(() => {
  return !props.useInfiniteScroll && props.showPaginationFooter;
});

defineExpose({ openContactExportDialog });
</script>

<template>
  <section
    class="flex w-full h-full gap-4 overflow-hidden justify-evenly bg-n-surface-1"
  >
    <div class="flex flex-col w-full h-full transition-all duration-300">
      <ContactListHeaderWrapper
        ref="contactListHeaderWrapper"
        :show-search="isNotSegmentView && !isActiveView"
        :search-value="searchValue"
        :active-sort="activeSort"
        :active-ordering="activeOrdering"
        :header-title="headerTitle"
        :active-segment="activeSegment"
        :segments-id="segmentsId"
        :has-applied-filters="hasAppliedFilters"
        :is-label-view="isLabelView"
        :is-active-view="isActiveView"
        :view-mode="viewMode"
        :show-view-toggle="showViewToggle"
        :selected-contact-ids="selectedContactIds"
        @update:sort="emit('update:sort', $event)"
        @update:view-mode="emit('update:viewMode', $event)"
        @search="emit('search', $event)"
        @apply-filter="emit('applyFilter', $event)"
        @clear-filters="emit('clearFilters')"
        @contact-created="emit('contactCreated')"
      />
      <main class="flex-1 overflow-y-auto">
        <div class="w-full mx-auto">
          <ContactsActiveFiltersPreview
            v-if="showActiveFiltersPreview"
            :active-segment="activeSegment"
            @clear-filters="emit('clearFilters')"
            @open-filter="openFilter"
          />
          <slot name="default" />
          <ContactsLoadMore
            v-if="showLoadMore"
            :is-loading="isLoadingMore"
            @load-more="emit('loadMore')"
          />
        </div>
      </main>
      <footer
        v-if="showPagination"
        class="sticky bottom-0 z-0 px-4 pb-4 sm:px-6 lg:px-8"
      >
        <PaginationFooter
          fluid
          current-page-info="CONTACTS_LAYOUT.PAGINATION_FOOTER.SHOWING"
          :current-page="currentPage"
          :total-items="totalItems"
          :items-per-page="itemsPerPage"
          :per-page-options="perPageOptions"
          @update:current-page="updateCurrentPage"
          @update:items-per-page="emit('update:itemsPerPage', $event)"
        />
      </footer>
    </div>
  </section>
</template>
