<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import filterQueryGenerator from 'dashboard/helper/filterQueryGenerator';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  selectedContactIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['export']);

const { t } = useI18n();
const route = useRoute();
const store = useStore();

const dialogRef = ref(null);
const exportScope = ref('current');
const selectedColumns = ref([
  'id',
  'name',
  'phone_1',
  'phone_2',
  'phone_3',
  'classification',
  'governorate',
  'district',
  'neighborhood',
  'street',
]);

const segments = useMapGetter('customViews/getContactCustomViews');
const appliedFilters = useMapGetter('contacts/getAppliedContactFilters');
const uiFlags = useMapGetter('contacts/getUIFlags');
const contactAttributes = useMapGetter('attributes/getContactAttributes');
const isExportingContact = computed(() => uiFlags.value.isExporting);

const activeSegmentId = computed(() => route.params.segmentId);
const activeSegment = computed(() =>
  activeSegmentId.value
    ? segments.value.find(view => view.id === Number(activeSegmentId.value))
    : undefined
);
const selectedCount = computed(() => props.selectedContactIds.length);
const hasSelectedContacts = computed(() => selectedCount.value > 0);
const hasScopedView = computed(
  () =>
    (activeSegmentId.value && activeSegment.value) ||
    route.params.label ||
    appliedFilters.value.length > 0
);

const standardExportColumns = computed(() => [
  {
    value: 'id',
    icon: 'i-lucide-hash',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.ID'),
  },
  {
    value: 'name',
    icon: 'i-lucide-user',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.NAME'),
  },
  {
    value: 'email',
    icon: 'i-lucide-mail',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.EMAIL'),
    direction: 'ltr',
  },
  {
    value: 'identifier',
    icon: 'i-lucide-tag',
    label: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.IDENTIFIER'
    ),
    direction: 'ltr',
  },
  {
    value: 'classification',
    icon: 'i-lucide-tag',
    label: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.CLASSIFICATION'
    ),
  },
  {
    value: 'phone_1',
    icon: 'i-lucide-phone',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.PHONE_1'),
    direction: 'ltr',
  },
  {
    value: 'phone_2',
    icon: 'i-lucide-phone',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.PHONE_2'),
    direction: 'ltr',
  },
  {
    value: 'phone_3',
    icon: 'i-lucide-phone',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.PHONE_3'),
    direction: 'ltr',
  },
  {
    value: 'governorate',
    icon: 'i-lucide-map-pin',
    label: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.GOVERNORATE'
    ),
  },
  {
    value: 'district',
    icon: 'i-lucide-map-pin',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.DISTRICT'),
  },
  {
    value: 'neighborhood',
    icon: 'i-lucide-map-pin',
    label: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.NEIGHBORHOOD'
    ),
  },
  {
    value: 'street',
    icon: 'i-lucide-map-pin',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.STREET'),
  },
  {
    value: 'created_at',
    icon: 'i-lucide-calendar-plus',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.CREATED'),
  },
  {
    value: 'updated_at',
    icon: 'i-lucide-calendar-clock',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.UPDATED'),
  },
  {
    value: 'last_activity_at',
    icon: 'i-lucide-activity',
    label: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.LAST_ACTIVITY'
    ),
  },
]);

const customExportColumns = computed(() =>
  contactAttributes.value.map(attribute => ({
    value: `custom_attribute:${attribute.attributeKey}`,
    icon: 'i-lucide-sliders-horizontal',
    label: attribute.attributeDisplayName,
    description: attribute.attributeKey,
    isCustomAttribute: true,
  }))
);

const exportColumns = computed(() => [
  ...standardExportColumns.value,
  ...customExportColumns.value,
]);

const hasSelectedColumns = computed(() => selectedColumns.value.length > 0);
const allColumnValues = computed(() => exportColumns.value.map(c => c.value));

const toggleColumn = (column, checked) => {
  selectedColumns.value = checked
    ? [...new Set([...selectedColumns.value, column])]
    : selectedColumns.value.filter(selectedColumn => selectedColumn !== column);
};

const selectAllColumns = () => {
  selectedColumns.value = [...allColumnValues.value];
};

const clearAllColumns = () => {
  selectedColumns.value = [];
};

const exportScopeLabel = computed(() => {
  if (activeSegmentId.value && activeSegment.value) {
    return t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.SCOPE.SEGMENT');
  }
  if (route.params.label) {
    return t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.SCOPE.CURRENT_LABEL'
    );
  }
  if (appliedFilters.value.length > 0) {
    return t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.SCOPE.FILTERED');
  }
  return t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.SCOPE.ALL');
});

const scopeOptions = computed(() => {
  const options = [];

  if (hasSelectedContacts.value) {
    options.push({
      value: 'selected',
      icon: 'i-lucide-check-square',
      label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.SCOPE.SELECTED', {
        count: selectedCount.value,
      }),
    });
  }

  if (hasScopedView.value) {
    options.push({
      value: 'current',
      icon: 'i-lucide-list-filter',
      label: exportScopeLabel.value,
    });
  }

  options.push({
    value: 'all',
    icon: 'i-lucide-users',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.SCOPE.ALL'),
  });

  return options;
});

const selectedScopeOption = computed(() =>
  scopeOptions.value.find(option => option.value === exportScope.value)
);

const exportContacts = async () => {
  let query = { payload: [] };

  if (exportScope.value === 'selected') {
    query = { payload: [], selectedIds: props.selectedContactIds };
  } else if (exportScope.value === 'all') {
    query = { payload: [], label: '' };
  } else if (activeSegmentId.value && activeSegment.value) {
    query = activeSegment.value.query;
  } else if (appliedFilters.value.length > 0) {
    query = filterQueryGenerator(appliedFilters.value);
  }

  emit('export', {
    ...query,
    label:
      exportScope.value === 'current' && route.params.label
        ? route.params.label
        : query.label || '',
    columnNames: selectedColumns.value,
  });
};

const handleDialogConfirm = async () => {
  await exportContacts();
};

const closeDialog = () => dialogRef.value?.close();

watch(
  [hasSelectedContacts, hasScopedView],
  ([hasSelected, hasScope]) => {
    if (hasSelected) {
      exportScope.value = 'selected';
    } else if (hasScope) {
      exportScope.value = 'current';
    } else {
      exportScope.value = 'all';
    }
  },
  { immediate: true }
);

onMounted(() => {
  if (!contactAttributes.value.length) {
    store.dispatch('attributes/get');
  }
});

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    width="7xl"
    position="top"
    overflow-y-auto
  >
    <Button
      icon="i-lucide-x"
      color="slate"
      variant="faded"
      size="md"
      type="button"
      class="absolute top-5 ltr:right-5 rtl:left-5 !rounded-full !size-10"
      @click="closeDialog"
    />

    <div class="flex flex-col gap-4">
      <div class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_24rem]">
        <section class="p-4 border rounded-xl border-n-weak bg-n-alpha-1">
          <div class="flex items-start justify-between gap-4">
            <div class="min-w-0">
              <div
                class="flex items-center gap-2 text-base font-semibold text-n-slate-12"
              >
                <span class="i-lucide-columns-3 size-5 text-n-blue-11" />
                {{
                  t(
                    'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.TITLE'
                  )
                }}
              </div>
              <p class="mt-1 mb-0 text-sm text-n-slate-11">
                {{
                  t(
                    'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.DESCRIPTION'
                  )
                }}
              </p>
            </div>
            <div class="flex items-center gap-3 shrink-0">
              <div class="flex items-center gap-1.5 text-xs">
                <button
                  type="button"
                  class="font-medium text-n-blue-11 hover:text-n-blue-12 transition-colors"
                  @click="selectAllColumns"
                >
                  {{
                    t(
                      'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.SELECT_ALL'
                    )
                  }}
                </button>
                <span class="text-n-slate-8">·</span>
                <button
                  type="button"
                  class="font-medium text-n-slate-10 hover:text-n-slate-12 transition-colors"
                  @click="clearAllColumns"
                >
                  {{
                    t(
                      'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.CLEAR'
                    )
                  }}
                </button>
              </div>
              <span
                class="px-2.5 py-1 text-xs font-semibold rounded-md bg-n-blue-4 text-n-blue-11"
              >
                {{
                  t(
                    'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.SELECTED',
                    { count: selectedColumns.length }
                  )
                }}
              </span>
            </div>
          </div>

          <div class="flex flex-col gap-4 mt-4">
            <div>
              <p
                class="mb-2 text-xs font-semibold uppercase tracking-wide text-n-slate-9"
              >
                {{
                  t(
                    'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.STANDARD'
                  )
                }}
              </p>
              <div class="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
                <label
                  v-for="column in standardExportColumns"
                  :key="column.value"
                  class="flex items-center gap-3 px-3 py-2.5 transition-all border rounded-lg cursor-pointer"
                  :class="
                    selectedColumns.includes(column.value)
                      ? 'border-n-brand/40 bg-n-brand/5 shadow-sm'
                      : 'border-n-weak bg-n-background hover:bg-n-alpha-1'
                  "
                >
                  <span
                    class="flex items-center justify-center rounded-md size-7 transition-colors"
                    :class="
                      selectedColumns.includes(column.value)
                        ? 'bg-n-brand/10 text-n-blue-11'
                        : 'bg-n-alpha-1 text-n-slate-10'
                    "
                  >
                    <span class="size-4" :class="column.icon" />
                  </span>
                  <span class="min-w-0 flex-1">
                    <span
                      :dir="column.direction || 'auto'"
                      class="block text-sm font-medium truncate text-n-slate-12"
                    >
                      {{ column.label }}
                    </span>
                  </span>
                  <Checkbox
                    :model-value="selectedColumns.includes(column.value)"
                    @change="
                      event => toggleColumn(column.value, event.target.checked)
                    "
                  />
                </label>
              </div>
            </div>
            <div
              v-if="customExportColumns.length"
              class="pt-3 border-t border-n-weak"
            >
              <p
                class="mb-2 text-xs font-semibold uppercase tracking-wide text-n-slate-9"
              >
                {{
                  t(
                    'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.CUSTOM'
                  )
                }}
              </p>
              <div class="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
                <label
                  v-for="column in customExportColumns"
                  :key="column.value"
                  class="flex items-center gap-3 px-3 py-2.5 transition-all border rounded-lg cursor-pointer"
                  :class="
                    selectedColumns.includes(column.value)
                      ? 'border-n-brand/40 bg-n-brand/5 shadow-sm'
                      : 'border-n-weak bg-n-background hover:bg-n-alpha-1'
                  "
                >
                  <span
                    class="flex items-center justify-center rounded-md size-7 transition-colors"
                    :class="
                      selectedColumns.includes(column.value)
                        ? 'bg-n-brand/10 text-n-blue-11'
                        : 'bg-n-alpha-1 text-n-slate-10'
                    "
                  >
                    <span class="size-4" :class="column.icon" />
                  </span>
                  <span class="min-w-0 flex-1">
                    <span
                      class="block text-sm font-medium truncate text-n-slate-12"
                    >
                      {{ column.label }}
                    </span>
                    <span
                      v-if="column.description"
                      dir="ltr"
                      class="block text-xs truncate text-n-slate-10"
                    >
                      {{ column.description }}
                    </span>
                  </span>
                  <Checkbox
                    :model-value="selectedColumns.includes(column.value)"
                    @change="
                      event => toggleColumn(column.value, event.target.checked)
                    "
                  />
                </label>
              </div>
            </div>
          </div>
        </section>

        <div class="grid gap-4">
          <section class="p-4 border rounded-xl border-n-weak bg-n-alpha-1">
            <div
              class="flex items-center gap-2 text-base font-semibold text-n-slate-12"
            >
              <span class="i-lucide-file-spreadsheet size-5 text-n-teal-11" />
              {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.FORMAT') }}
            </div>
            <div
              class="flex items-center justify-between gap-3 px-3 py-3 mt-4 border rounded-lg border-n-weak bg-n-background"
            >
              <span class="text-sm font-medium text-n-slate-11">
                {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.XLSX') }}
              </span>
              <span class="i-lucide-check-circle-2 size-5 text-n-teal-11" />
            </div>
          </section>

          <section class="p-4 border rounded-xl border-n-weak bg-n-alpha-1">
            <div
              class="flex items-center gap-2 text-base font-semibold text-n-slate-12"
            >
              <span class="i-lucide-send-to-back size-5 text-n-blue-11" />
              {{
                t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.SCOPE.TITLE')
              }}
            </div>
            <div class="grid gap-2 mt-4">
              <button
                v-for="option in scopeOptions"
                :key="option.value"
                type="button"
                class="flex items-center gap-3 px-3 py-3 text-sm font-semibold transition-colors border rounded-lg text-start"
                :class="
                  exportScope === option.value
                    ? 'border-n-brand bg-n-brand text-white shadow-sm'
                    : 'border-n-weak bg-n-background text-n-slate-12 hover:bg-n-alpha-1'
                "
                @click="exportScope = option.value"
              >
                <span class="size-4 shrink-0" :class="option.icon" />
                <span class="min-w-0 truncate">{{ option.label }}</span>
                <span
                  v-if="exportScope === option.value"
                  class="i-lucide-check size-4 ltr:ml-auto rtl:mr-auto"
                />
              </button>
            </div>
          </section>
        </div>
      </div>

      <section
        class="grid gap-3 p-4 border rounded-xl border-n-weak bg-n-alpha-1 md:grid-cols-3"
      >
        <div class="flex items-center gap-3 p-3 rounded-lg bg-n-background">
          <span
            class="flex items-center justify-center rounded-lg size-10 bg-n-blue-4 text-n-blue-11"
          >
            <span class="i-lucide-table-properties size-5" />
          </span>
          <div class="min-w-0">
            <div class="text-xs text-n-slate-10">
              {{
                t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.SUMMARY.COLUMNS'
                )
              }}
            </div>
            <div class="text-sm font-semibold truncate text-n-slate-12">
              {{
                t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.COLUMNS.SELECTED',
                  {
                    count: selectedColumns.length,
                  }
                )
              }}
            </div>
          </div>
        </div>
        <div class="flex items-center gap-3 p-3 rounded-lg bg-n-background">
          <span
            class="flex items-center justify-center rounded-lg size-10 bg-n-teal-4 text-n-teal-11"
          >
            <span class="i-lucide-file-check-2 size-5" />
          </span>
          <div class="min-w-0">
            <div class="text-xs text-n-slate-10">
              {{
                t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.SUMMARY.FORMAT'
                )
              }}
            </div>
            <div class="text-sm font-semibold truncate text-n-slate-12">
              {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.XLSX') }}
            </div>
          </div>
        </div>
        <div class="flex items-center gap-3 p-3 rounded-lg bg-n-background">
          <span
            class="flex items-center justify-center rounded-lg size-10 bg-n-amber-4 text-n-amber-11"
          >
            <span class="i-lucide-users size-5" />
          </span>
          <div class="min-w-0">
            <div class="text-xs text-n-slate-10">
              {{
                t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.SUMMARY.SCOPE')
              }}
            </div>
            <div class="text-sm font-semibold truncate text-n-slate-12">
              {{ selectedScopeOption?.label }}
            </div>
          </div>
        </div>
      </section>

      <div
        v-if="isExportingContact"
        class="flex items-center gap-3 px-4 py-3 text-sm border rounded-xl border-n-blue-5 bg-n-blue-3 text-n-blue-12"
      >
        <span class="i-lucide-loader-circle animate-spin size-4" />
        <span>
          {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.PROGRESS') }}
        </span>
      </div>
    </div>

    <template #footer>
      <div
        class="sticky bottom-0 z-10 flex flex-col-reverse w-full gap-3 px-6 py-4 -mx-6 -mb-6 border-t sm:flex-row sm:items-center sm:justify-end bg-n-background/95 backdrop-blur-sm border-n-weak rounded-b-xl"
      >
        <Button
          :label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CANCEL')"
          color="slate"
          variant="outline"
          size="lg"
          type="button"
          class="w-full sm:w-64"
          @click="closeDialog"
        />
        <Button
          :label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.EXPORT_CONTACT.CONFIRM')"
          icon="i-lucide-download"
          trailing-icon
          color="blue"
          size="lg"
          type="button"
          class="w-full sm:w-64"
          :is-loading="isExportingContact"
          :disabled="isExportingContact || !hasSelectedColumns"
          @click="handleDialogConfirm"
        />
      </div>
    </template>
  </Dialog>
</template>
