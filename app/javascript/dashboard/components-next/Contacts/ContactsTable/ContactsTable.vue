<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import ContactsTableHeader from './ContactsTableHeader.vue';
import ContactsTableRow from './ContactsTableRow.vue';

const props = defineProps({
  contacts: { type: Array, required: true },
  selectedContactIds: { type: Array, default: () => [] },
  activeSort: { type: String, default: 'last_activity_at' },
  activeOrdering: { type: String, default: '' },
});

const emit = defineEmits(['toggleContact', 'toggleAll', 'update:sort']);

const route = useRoute();
const router = useRouter();

const selectedIdsSet = computed(() => new Set(props.selectedContactIds || []));
const visibleContactIds = computed(() =>
  props.contacts.map(contact => contact.id)
);
const selectedVisibleCount = computed(() => {
  return visibleContactIds.value.filter(id => selectedIdsSet.value.has(id))
    .length;
});
const allSelected = computed(() => {
  return (
    visibleContactIds.value.length > 0 &&
    selectedVisibleCount.value === visibleContactIds.value.length
  );
});
const isIndeterminate = computed(() => {
  return selectedVisibleCount.value > 0 && !allSelected.value;
});

const isSelected = id => selectedIdsSet.value.has(id);

const onClickViewDetails = async id => {
  const routeTypes = {
    contacts_dashboard_segments_index: ['contacts_edit_segment', 'segmentId'],
    contacts_dashboard_labels_index: ['contacts_edit_label', 'label'],
  };
  const [name, paramKey] = routeTypes[route.name] || ['contacts_edit'];
  const params = {
    contactId: id,
    ...(paramKey && { [paramKey]: route.params[paramKey] }),
  };

  await router.push({ name, params, query: route.query });
};
</script>

<template>
  <div
    class="w-full overflow-hidden border shadow-sm rounded-xl bg-n-solid-1 border-n-weak"
  >
    <div
      class="flex items-center justify-between gap-3 px-4 py-3 border-b border-n-weak bg-n-alpha-1"
    >
      <div class="flex items-center gap-2 text-sm text-n-slate-11">
        <span class="i-lucide-list-checks size-4" />
        <span class="font-medium text-n-slate-12">
          {{
            $t('CONTACTS_BULK_ACTIONS.SELECTED_COUNT', {
              count: selectedVisibleCount,
            })
          }}
        </span>
      </div>
    </div>
    <div class="w-full overflow-x-auto">
      <table
        class="w-full text-[13px] border-collapse table-fixed min-w-[96rem] font-inter [font-feature-settings:'tnum']"
      >
        <colgroup>
          <col class="w-12" />
          <col class="w-[22rem]" />
          <col class="w-[14rem]" />
          <col class="w-[14rem]" />
          <col class="w-[14rem]" />
          <col class="w-[14rem]" />
          <col class="w-[14rem]" />
        </colgroup>
        <ContactsTableHeader
          :active-sort="activeSort"
          :active-ordering="activeOrdering"
          :all-selected="allSelected"
          :is-indeterminate="isIndeterminate"
          @toggle-all="emit('toggleAll', $event)"
          @update:sort="emit('update:sort', $event)"
        />
        <tbody>
          <ContactsTableRow
            v-for="contact in contacts"
            :key="contact.id"
            :contact="contact"
            :is-selected="isSelected(contact.id)"
            @select="value => emit('toggleContact', { id: contact.id, value })"
            @show-contact="onClickViewDetails"
          />
        </tbody>
      </table>
    </div>
  </div>
</template>
