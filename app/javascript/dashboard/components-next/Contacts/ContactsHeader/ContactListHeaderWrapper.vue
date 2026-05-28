<script setup>
import { ref, computed, unref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useRouter } from 'vue-router';
import { useAlert, useTrack } from 'dashboard/composables';
import { CONTACTS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import filterQueryGenerator from 'dashboard/helper/filterQueryGenerator';
import contactFilterItems from 'dashboard/routes/dashboard/contacts/contactFilterItems';
import {
  DuplicateContactException,
  DuplicatePhoneException,
  ExceptionWithMessage,
} from 'shared/helpers/CustomErrors';
import { generateValuesForEditCustomViews } from 'dashboard/helper/customViewsHelper';
import countries from 'shared/constants/countries';
import {
  useCamelCase,
  useSnakeCase,
} from 'dashboard/composables/useTransformKeys';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import ContactsHeader from 'dashboard/components-next/Contacts/ContactsHeader/ContactHeader.vue';
import CreateNewContactDialog from 'dashboard/components-next/Contacts/ContactsForm/CreateNewContactDialog.vue';
import ContactExportDialog from 'dashboard/components-next/Contacts/ContactsForm/ContactExportDialog.vue';
import ContactImportDialog from 'dashboard/components-next/Contacts/ContactsForm/ContactImportDialog.vue';
import CreateSegmentDialog from 'dashboard/components-next/Contacts/ContactsForm/CreateSegmentDialog.vue';
import DeleteSegmentDialog from 'dashboard/components-next/Contacts/ContactsForm/DeleteSegmentDialog.vue';
import ContactsFilter from 'dashboard/components-next/filter/ContactsFilter.vue';

const props = defineProps({
  showSearch: { type: Boolean, default: true },
  searchValue: { type: String, default: '' },
  activeSort: { type: String, default: 'last_activity_at' },
  activeOrdering: { type: String, default: '' },
  headerTitle: { type: String, default: '' },
  segmentsId: { type: [String, Number], default: 0 },
  activeSegment: { type: Object, default: null },
  hasAppliedFilters: { type: Boolean, default: false },
  isLabelView: { type: Boolean, default: false },
  isActiveView: { type: Boolean, default: false },
  viewMode: { type: String, default: 'table' },
  showViewToggle: { type: Boolean, default: true },
  selectedContactIds: { type: Array, default: () => [] },
});

const emit = defineEmits([
  'update:sort',
  'search',
  'applyFilter',
  'clearFilters',
  'update:viewMode',
  'contactCreated',
]);

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const createNewContactDialogRef = ref(null);
const contactExportDialogRef = ref(null);
const contactImportDialogRef = ref(null);
const createSegmentDialogRef = ref(null);
const deleteSegmentDialogRef = ref(null);
const phoneDuplicateDialogRef = ref(null);
const phoneDuplicateMessage = ref('');

const showFiltersModal = ref(false);
const appliedFilter = ref([]);
const segmentsQuery = ref({});

const appliedFilters = useMapGetter('contacts/getAppliedContactFiltersV4');
const contactAttributes = useMapGetter('attributes/getContactAttributes');
const labels = useMapGetter('labels/getLabels');
const hasActiveSegments = computed(
  () => props.activeSegment && props.segmentsId !== 0
);
const activeSegmentName = computed(() => props.activeSegment?.name);

const openCreateNewContactDialog = () => {
  createNewContactDialogRef.value?.dialogRef.open();
};
const openContactImportDialog = () =>
  contactImportDialogRef.value?.dialogRef.open();
const openContactExportDialog = () =>
  contactExportDialogRef.value?.dialogRef.open();
const openCreateSegmentDialog = () =>
  createSegmentDialogRef.value?.dialogRef.open();
const openDeleteSegmentDialog = () =>
  deleteSegmentDialogRef.value?.dialogRef.open();

const parsedPhoneDuplicate = computed(() => {
  const msg = phoneDuplicateMessage.value;
  if (!msg) return { phone: '', contactName: '' };
  const parts = msg.split(' is already assigned to contact: ');
  return {
    phone: parts[0]?.replace('Phone ', '').trim() || '',
    contactName: parts[1]?.trim() || '',
  };
});

const showPhoneDuplicateDialog = message => {
  phoneDuplicateMessage.value = message;
  phoneDuplicateDialogRef.value?.open();
};

const onCreate = async contact => {
  try {
    await store.dispatch('contacts/create', contact);
    createNewContactDialogRef.value?.onSuccess();
    emit('contactCreated');
    useAlert(
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.SUCCESS_MESSAGE')
    );
  } catch (error) {
    const i18nPrefix = 'CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION';
    if (error instanceof DuplicatePhoneException) {
      showPhoneDuplicateDialog(error.data);
    } else if (error instanceof DuplicateContactException) {
      if (error.data.includes('email')) {
        useAlert(t(`${i18nPrefix}.EMAIL_ADDRESS_DUPLICATE`));
      } else if (error.data.includes('phone_number')) {
        useAlert(t(`${i18nPrefix}.PHONE_NUMBER_DUPLICATE`));
      }
    } else if (error instanceof ExceptionWithMessage) {
      useAlert(error.data);
    } else {
      useAlert(t(`${i18nPrefix}.ERROR_MESSAGE`));
    }
  }
};

const onImport = async file => {
  try {
    const result = await store.dispatch('contacts/import', file);
    contactImportDialogRef.value?.dialogRef.close();
    useAlert(
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.SUCCESS_MESSAGE', {
        count: result?.processed_records ?? 0,
      })
    );
    useTrack(CONTACTS_EVENTS.IMPORT_SUCCESS);
    emit('clearFilters');
  } catch (error) {
    useAlert(
      error.message ??
        t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.ERROR_MESSAGE')
    );
    useTrack(CONTACTS_EVENTS.IMPORT_FAILURE);
  }
};

const onExport = async query => {
  try {
    await store.dispatch('contacts/export', query);
    contactExportDialogRef.value?.dialogRef.close();
    useAlert(
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.SUCCESS_MESSAGE')
    );
  } catch (error) {
    useAlert(
      error.message ||
        t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.ERROR_MESSAGE')
    );
  }
};

const onCreateSegment = async payload => {
  try {
    const payloadData = {
      ...payload,
      query: segmentsQuery.value,
    };
    const response = await store.dispatch('customViews/create', payloadData);
    createSegmentDialogRef.value?.dialogRef.close();
    useAlert(
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.CREATE_SEGMENT.SUCCESS_MESSAGE')
    );
    const segmentId = response?.data?.id;
    if (!segmentId) return;
    // Navigate to the created segment
    router.push({
      name: 'contacts_dashboard_segments_index',
      params: { segmentId },
      query: { page: 1 },
    });
  } catch {
    useAlert(
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.CREATE_SEGMENT.ERROR_MESSAGE')
    );
  }
};

const onDeleteSegment = async payload => {
  try {
    await store.dispatch('customViews/delete', {
      id: Number(props.segmentsId),
      ...payload,
    });
    router.push({
      name: 'contacts_dashboard_index',
      query: {
        page: 1,
      },
    });
    deleteSegmentDialogRef.value?.dialogRef.close();
    useAlert(
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.DELETE_SEGMENT.SUCCESS_MESSAGE')
    );
  } catch (error) {
    useAlert(
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.DELETE_SEGMENT.ERROR_MESSAGE')
    );
  }
};

const closeAdvanceFiltersModal = () => {
  showFiltersModal.value = false;
  appliedFilter.value = [];
};

const clearFilters = async () => {
  emit('clearFilters');
};

const onApplyFilter = async payload => {
  payload = useSnakeCase(payload);
  segmentsQuery.value = filterQueryGenerator(payload);
  emit('applyFilter', filterQueryGenerator(payload));
  showFiltersModal.value = false;
};

const onUpdateSegment = async (payload, segmentName) => {
  payload = useSnakeCase(payload);
  const payloadData = {
    ...props.activeSegment,
    name: segmentName,
    query: filterQueryGenerator(payload),
  };
  await store.dispatch('customViews/update', payloadData);
  closeAdvanceFiltersModal();
};

const setParamsForEditSegmentModal = () => {
  return {
    countries,
    filterTypes: contactFilterItems,
    allCustomAttributes: useSnakeCase(contactAttributes.value),
    labels: labels.value || [],
  };
};

const initializeSegmentToFilterModal = segment => {
  const query = unref(segment)?.query?.payload;
  if (!Array.isArray(query)) return;

  const newFilters = query.map(filter => {
    const transformed = useCamelCase(filter);
    const values = Array.isArray(transformed.values)
      ? generateValuesForEditCustomViews(
          useSnakeCase(filter),
          setParamsForEditSegmentModal()
        )
      : [];

    return {
      attributeKey: transformed.attributeKey,
      attributeModel: transformed.attributeModel,
      customAttributeType: transformed.customAttributeType,
      filterOperator: transformed.filterOperator,
      queryOperator: transformed.queryOperator ?? 'and',
      values,
    };
  });

  appliedFilter.value = [...appliedFilter.value, ...newFilters];
};

const onToggleFilters = () => {
  appliedFilter.value = [];
  if (hasActiveSegments.value) {
    initializeSegmentToFilterModal(props.activeSegment);
  } else {
    appliedFilter.value = props.hasAppliedFilters
      ? [...appliedFilters.value]
      : [
          {
            attributeKey: 'name',
            filterOperator: 'equal_to',
            values: '',
            queryOperator: 'and',
            attributeModel: 'standard',
          },
        ];
  }
  showFiltersModal.value = true;
};

defineExpose({
  onToggleFilters,
  openContactExportDialog,
});
</script>

<template>
  <ContactsHeader
    :show-search="showSearch"
    :search-value="searchValue"
    :active-sort="activeSort"
    :active-ordering="activeOrdering"
    :header-title="headerTitle"
    :is-segments-view="hasActiveSegments"
    :is-label-view="isLabelView"
    :is-active-view="isActiveView"
    :has-active-filters="hasAppliedFilters"
    :view-mode="viewMode"
    :show-view-toggle="showViewToggle"
    :button-label="t('CONTACTS_LAYOUT.HEADER.MESSAGE_BUTTON')"
    @search="emit('search', $event)"
    @update:sort="emit('update:sort', $event)"
    @add="openCreateNewContactDialog"
    @import="openContactImportDialog"
    @export="openContactExportDialog"
    @filter="onToggleFilters"
    @create-segment="openCreateSegmentDialog"
    @delete-segment="openDeleteSegmentDialog"
    @update:view-mode="emit('update:viewMode', $event)"
  >
    <template #filter>
      <div
        class="absolute mt-1 ltr:-right-52 rtl:-left-52 sm:ltr:right-0 sm:rtl:left-0 top-full"
      >
        <ContactsFilter
          v-if="showFiltersModal"
          v-model="appliedFilter"
          :segment-name="activeSegmentName"
          :is-segment-view="hasActiveSegments"
          @apply-filter="onApplyFilter"
          @update-segment="onUpdateSegment"
          @close="closeAdvanceFiltersModal"
          @clear-filters="clearFilters"
        />
      </div>
    </template>
  </ContactsHeader>

  <CreateNewContactDialog ref="createNewContactDialogRef" @create="onCreate" />
  <ContactExportDialog
    ref="contactExportDialogRef"
    :selected-contact-ids="selectedContactIds"
    @export="onExport"
  />
  <ContactImportDialog ref="contactImportDialogRef" @import="onImport" />
  <CreateSegmentDialog ref="createSegmentDialogRef" @create="onCreateSegment" />
  <DeleteSegmentDialog ref="deleteSegmentDialogRef" @delete="onDeleteSegment" />

  <Dialog
    ref="phoneDuplicateDialogRef"
    :show-cancel-button="false"
    :show-confirm-button="false"
    width="sm"
  >
    <div class="flex flex-col items-center gap-5 py-2 text-center">
      <div
        class="flex items-center justify-center rounded-full size-16 bg-n-ruby-4"
      >
        <span class="i-lucide-phone-off size-8 text-n-ruby-11" />
      </div>

      <div class="space-y-1">
        <h3 class="text-base font-semibold text-n-slate-12">
          {{
            t(
              'CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.DUPLICATE_PHONE_TITLE'
            )
          }}
        </h3>
        <p class="text-sm text-n-slate-10">
          {{
            t(
              'CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.DUPLICATE_PHONE_SUBTITLE'
            )
          }}
        </p>
      </div>

      <div
        class="flex items-center justify-center w-full gap-2 px-4 py-3 rounded-xl bg-n-alpha-2 border border-n-weak"
      >
        <span class="i-lucide-phone size-4 text-n-slate-10 shrink-0" />
        <span
          dir="ltr"
          class="font-mono text-sm font-semibold tracking-wide text-n-slate-12"
        >
          {{ parsedPhoneDuplicate.phone }}
        </span>
      </div>

      <div
        class="flex items-center w-full gap-3 px-4 py-3 rounded-xl bg-n-ruby-3 border border-n-ruby-5"
      >
        <span class="i-lucide-user size-4 text-n-ruby-11 shrink-0" />
        <div class="text-start min-w-0">
          <p class="text-xs text-n-ruby-10">
            {{
              t(
                'CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.DUPLICATE_PHONE_ASSIGNED_TO'
              )
            }}
          </p>
          <p class="text-sm font-semibold truncate text-n-ruby-12">
            {{ parsedPhoneDuplicate.contactName }}
          </p>
        </div>
      </div>

      <button
        type="button"
        class="w-full px-4 py-2.5 text-sm font-semibold text-white transition-colors rounded-lg bg-n-ruby-9 hover:bg-n-ruby-10"
        @click="phoneDuplicateDialogRef?.close()"
      >
        {{
          t(
            'CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.DUPLICATE_PHONE_DISMISS'
          )
        }}
      </button>
    </div>
  </Dialog>
</template>
