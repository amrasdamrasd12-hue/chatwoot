<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import ContactAPI from 'dashboard/api/contacts';
import { downloadBlobFile } from 'dashboard/helper/downloadHelper';

const emit = defineEmits(['import']);
const { t } = useI18n();
const store = useStore();

const uiFlags = useMapGetter('contacts/getUIFlags');
const contactAttributes = useMapGetter('attributes/getContactAttributes');
const isImportingContact = computed(() => uiFlags.value.isImporting);

const dialogRef = ref(null);
const fileInput = ref(null);

const hasSelectedFile = ref(null);
const selectedFileName = ref('');
const isDownloadingTemplate = ref(false);
const isPreviewingImport = ref(false);
const previewHeaders = ref([]);
const previewRows = ref([]);
const previewError = ref('');

const selectedTemplateColumns = ref([
  'name',
  'phone_1',
  'phone_2',
  'classification',
  'governorate',
  'district',
  'neighborhood',
  'street',
]);

const standardTemplateColumns = computed(() => [
  {
    value: 'name',
    icon: 'i-lucide-user',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.NAME'),
    sample: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.PREVIEW.NAME'
    ),
  },
  {
    value: 'email',
    icon: 'i-lucide-mail',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.EMAIL'),
    sample: 'ahmed@example.com',
    direction: 'ltr',
  },
  {
    value: 'identifier',
    icon: 'i-lucide-tag',
    label: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.IDENTIFIER'
    ),
    sample: 'customer_1001',
    direction: 'ltr',
  },
  {
    value: 'classification',
    icon: 'i-lucide-tag',
    label: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.CLASSIFICATION'
    ),
    sample: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.PREVIEW.CLASSIFICATION'
    ),
  },
  {
    value: 'phone_1',
    icon: 'i-lucide-phone',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.PHONE_1'),
    sample: '+201001234567',
    direction: 'ltr',
  },
  {
    value: 'phone_2',
    icon: 'i-lucide-phone',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.PHONE_2'),
    sample: '+201009876543',
    direction: 'ltr',
  },
  {
    value: 'phone_3',
    icon: 'i-lucide-phone',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.PHONE_3'),
    sample: '',
    direction: 'ltr',
  },
  {
    value: 'governorate',
    icon: 'i-lucide-map-pin',
    label: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.GOVERNORATE'
    ),
    sample: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.PREVIEW.GOVERNORATE'
    ),
  },
  {
    value: 'district',
    icon: 'i-lucide-map-pin',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.DISTRICT'),
    sample: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.PREVIEW.DISTRICT'
    ),
  },
  {
    value: 'neighborhood',
    icon: 'i-lucide-map-pin',
    label: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.NEIGHBORHOOD'
    ),
    sample: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.PREVIEW.NEIGHBORHOOD'
    ),
  },
  {
    value: 'street',
    icon: 'i-lucide-map-pin',
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.STREET'),
    sample: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.PREVIEW.STREET'
    ),
  },
]);

const customTemplateColumns = computed(() =>
  contactAttributes.value.map(attribute => ({
    value: attribute.attributeKey,
    icon: 'i-lucide-sliders-horizontal',
    label: attribute.attributeDisplayName,
    description: attribute.attributeKey,
    sample: attribute.defaultValue || attribute.attributeDisplayName,
    isCustomAttribute: true,
  }))
);

const templateColumns = computed(() => [
  ...standardTemplateColumns.value,
  ...customTemplateColumns.value,
]);

const selectedTemplateColumnObjects = computed(() =>
  templateColumns.value.filter(column =>
    selectedTemplateColumns.value.includes(column.value)
  )
);

const hasImportPreview = computed(() => previewHeaders.value.length > 0);

const previewTableHeaders = computed(() => {
  if (hasImportPreview.value) return previewHeaders.value;
  return selectedTemplateColumnObjects.value.map(column => column.label);
});

const previewTableRows = computed(() => {
  if (hasImportPreview.value) return previewRows.value;
  return [selectedTemplateColumnObjects.value.map(column => column.sample)];
});

const columnDisplayMap = computed(() =>
  templateColumns.value.reduce((acc, column) => {
    acc[column.value] = column;
    return acc;
  }, {})
);

const previewColumns = computed(() =>
  previewTableHeaders.value.map(header => {
    const column = columnDisplayMap.value[header] || {};
    const isNumeric = /phone|mobile|هاتف|جوال/i.test(header);
    const isEmail = /email|mail|بريد/i.test(header);
    const isIdentifier = /identifier|id|معرّف|معرف/i.test(header);
    const isLongText = /notes|note|ملاحظ/i.test(header);

    return {
      key: header,
      label: column.label || header,
      description: column.label ? header : '',
      direction: column.direction || (isNumeric || isEmail ? 'ltr' : 'auto'),
      classes: [
        isLongText ? 'min-w-64 max-w-80' : '',
        isEmail ? 'min-w-64' : '',
        isNumeric || isIdentifier ? 'min-w-44' : '',
        !isLongText && !isEmail && !isNumeric && !isIdentifier
          ? 'min-w-40'
          : '',
      ]
        .filter(Boolean)
        .join(' '),
    };
  })
);

const previewCellValue = (row, index) => {
  const value = row[index];
  return value === undefined || value === null || value === '' ? '--' : value;
};

const previewCellClass = column => {
  if (column.direction === 'ltr') {
    return 'text-left font-mono tabular-nums';
  }

  return 'text-start';
};

const previewSubtitle = computed(() =>
  hasImportPreview.value
    ? t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.PREVIEW.FIRST_ROWS')
    : t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.PREVIEW.EXAMPLE')
);

const handleFileClick = () => fileInput.value?.click();

const selectedFileSize = computed(() => {
  if (!hasSelectedFile.value?.size) return '';
  const sizeInKb = hasSelectedFile.value.size / 1024;
  if (sizeInKb < 1024) return `${sizeInKb.toFixed(1)} KB`;
  return `${(sizeInKb / 1024).toFixed(1)} MB`;
});

function isValidExcelFile(file) {
  return Boolean(
    file &&
      (file.type ===
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
        file.name.toLowerCase().endsWith('.xlsx'))
  );
}

const isExcelFile = computed(() => {
  if (!hasSelectedFile.value) return false;
  return isValidExcelFile(hasSelectedFile.value);
});

const disableImport = computed(
  () => isImportingContact.value || !hasSelectedFile.value || !isExcelFile.value
);

const hasTemplateColumns = computed(
  () => selectedTemplateColumns.value.length > 0
);

const importSteps = computed(() => [
  {
    number: 1,
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.STEPS.UPLOAD'),
    isActive: true,
  },
  {
    number: 2,
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.STEPS.VALIDATE'),
    isActive: isExcelFile.value,
  },
  {
    number: 3,
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.STEPS.IMPORT'),
    isActive: isImportingContact.value,
  },
]);

const workbookChecks = computed(() => [
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHECKS.FORMAT'),
    value: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.XLSX_ONLY'),
    isReady: !hasSelectedFile.value || isExcelFile.value,
  },
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHECKS.SHEET'),
    value: t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHECKS.FIRST_SHEET'
    ),
    isReady: Boolean(hasSelectedFile.value),
  },
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHECKS.HEADER'),
    value: t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHECKS.HEADER_ROW'),
    isReady: Boolean(hasSelectedFile.value),
  },
]);

const processFileName = fileName => {
  const lastDotIndex = fileName.lastIndexOf('.');
  const extension = fileName.slice(lastDotIndex);
  const baseName = fileName.slice(0, lastDotIndex);

  return baseName.length > 28
    ? `${baseName.slice(0, 28)}...${extension}`
    : fileName;
};

async function loadImportPreview(file) {
  isPreviewingImport.value = true;

  try {
    const { data } = await ContactAPI.previewImport(file);
    previewHeaders.value = data.payload?.headers || [];
    previewRows.value = data.payload?.rows || [];
  } catch {
    previewError.value = t(
      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.PREVIEW.ERROR'
    );
  } finally {
    isPreviewingImport.value = false;
  }
}

const setSelectedFile = file => {
  hasSelectedFile.value = file || null;
  selectedFileName.value = file ? processFileName(file.name) : '';
  previewHeaders.value = [];
  previewRows.value = [];
  previewError.value = '';

  if (isValidExcelFile(file)) {
    loadImportPreview(file);
  }
};

const handleFileChange = () => {
  setSelectedFile(fileInput.value?.files[0]);
};

const handleDrop = event => {
  const file = event.dataTransfer?.files?.[0];
  if (!file) return;
  setSelectedFile(file);
};

const handleRemoveFile = () => {
  hasSelectedFile.value = null;
  if (fileInput.value) {
    fileInput.value.value = null;
  }
  selectedFileName.value = '';
  previewHeaders.value = [];
  previewRows.value = [];
  previewError.value = '';
};

const toggleTemplateColumn = (column, checked) => {
  selectedTemplateColumns.value = checked
    ? [...new Set([...selectedTemplateColumns.value, column])]
    : selectedTemplateColumns.value.filter(
        selectedColumn => selectedColumn !== column
      );
};

const selectAllTemplateColumns = () => {
  selectedTemplateColumns.value = templateColumns.value.map(c => c.value);
};

const clearAllTemplateColumns = () => {
  selectedTemplateColumns.value = [];
};

const downloadTemplate = async () => {
  if (!hasTemplateColumns.value || isDownloadingTemplate.value) return;
  isDownloadingTemplate.value = true;

  try {
    const response = await ContactAPI.importTemplate(
      selectedTemplateColumns.value
    );
    downloadBlobFile(
      'contacts_import_template.xlsx',
      response.data,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    );
  } catch {
    useAlert(t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.TEMPLATE.ERROR'));
  } finally {
    isDownloadingTemplate.value = false;
  }
};

const uploadFile = async () => {
  if (disableImport.value) return;
  emit('import', hasSelectedFile.value);
};

const closeDialog = () => dialogRef.value?.close();

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
    :title="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.TITLE')"
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
      <div class="flex items-center w-full gap-4 px-12">
        <template v-for="(step, index) in importSteps" :key="step.number">
          <div
            class="flex items-center gap-3 shrink-0"
            :class="step.isActive ? 'text-n-blue-11' : 'text-n-slate-10'"
          >
            <span
              class="flex items-center justify-center text-sm font-semibold border rounded-full size-9"
              :class="
                step.isActive
                  ? 'border-n-brand bg-n-brand/10 text-n-blue-11'
                  : 'border-n-strong bg-n-alpha-1 text-n-slate-10'
              "
            >
              {{ step.number }}
            </span>
            <span class="text-sm font-semibold whitespace-nowrap">
              {{ step.label }}
            </span>
          </div>
          <div
            v-if="index < importSteps.length - 1"
            class="h-px min-w-12 flex-1"
            :class="
              importSteps[index + 1].isActive ? 'bg-n-brand' : 'bg-n-strong'
            "
          />
        </template>
      </div>

      <div
        role="button"
        tabindex="0"
        class="flex flex-col items-center justify-center w-full gap-3 px-6 py-8 text-center transition-colors border border-dashed rounded-xl border-n-brand/70 bg-n-brand/5 hover:bg-n-brand/10"
        @click="handleFileClick"
        @keydown.enter.prevent="handleFileClick"
        @keydown.space.prevent="handleFileClick"
        @dragover.prevent
        @drop.prevent="handleDrop"
      >
        <span
          class="flex items-center justify-center border rounded-xl size-16 border-n-brand/30 bg-n-background text-n-blue-11 shadow-sm"
        >
          <span class="i-lucide-cloud-upload size-8" />
        </span>
        <span class="text-base font-semibold text-n-slate-12">
          {{
            hasSelectedFile
              ? selectedFileName
              : t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.DROPZONE_TITLE'
                )
          }}
        </span>
        <span class="max-w-xl text-sm text-n-slate-11">
          {{
            hasSelectedFile
              ? selectedFileSize
              : t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.DROPZONE_SUBTITLE'
                )
          }}
        </span>
        <Button
          :label="
            t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHOOSE_FILE')
          "
          icon="i-lucide-folder-open"
          color="blue"
          variant="outline"
          size="sm"
          type="button"
          @click.stop="handleFileClick"
        />
      </div>

      <div
        v-if="hasSelectedFile"
        class="flex items-center justify-between gap-3 px-4 py-3 border rounded-xl border-n-weak bg-n-alpha-1"
      >
        <div class="flex items-center min-w-0 gap-3">
          <span
            class="flex items-center justify-center rounded-lg size-10 bg-n-blue-4 text-n-blue-11"
          >
            <span class="i-lucide-file-spreadsheet size-5" />
          </span>
          <div class="min-w-0">
            <div class="text-sm font-semibold truncate text-n-slate-12">
              {{ selectedFileName }}
            </div>
            <div
              class="text-xs"
              :class="isExcelFile ? 'text-n-teal-11' : 'text-n-ruby-11'"
            >
              {{
                isExcelFile
                  ? t(
                      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.VALIDATION_READY'
                    )
                  : t(
                      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.VALIDATION_ERROR'
                    )
              }}
            </div>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <Button
            :label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHANGE')"
            color="slate"
            variant="outline"
            size="sm"
            type="button"
            @click="handleFileClick"
          />
          <Button
            icon="i-lucide-trash-2"
            color="ruby"
            variant="ghost"
            size="sm"
            type="button"
            @click="handleRemoveFile"
          />
        </div>
      </div>

      <div class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_22rem]">
        <section class="p-4 border rounded-xl border-n-weak bg-n-alpha-1">
          <div class="flex items-start justify-between gap-4">
            <div class="min-w-0">
              <div
                class="flex items-center gap-2 text-base font-semibold text-n-slate-12"
              >
                <span class="i-lucide-layout-grid size-5 text-n-blue-11" />
                {{
                  t(
                    'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.TITLE'
                  )
                }}
              </div>
              <p class="mt-1 mb-0 text-sm text-n-slate-11">
                {{
                  t(
                    'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.DESCRIPTION'
                  )
                }}
              </p>
            </div>
            <div class="flex items-center gap-3 shrink-0">
              <div class="flex items-center gap-1.5 text-xs">
                <button
                  type="button"
                  class="font-medium text-n-blue-11 hover:text-n-blue-12 transition-colors"
                  @click="selectAllTemplateColumns"
                >
                  {{
                    t(
                      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.SELECT_ALL'
                    )
                  }}
                </button>
                <span class="text-n-slate-8">·</span>
                <button
                  type="button"
                  class="font-medium text-n-slate-10 hover:text-n-slate-12 transition-colors"
                  @click="clearAllTemplateColumns"
                >
                  {{
                    t(
                      'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.CLEAR'
                    )
                  }}
                </button>
              </div>
              <span
                class="px-2.5 py-1 text-xs font-semibold rounded-md shrink-0 bg-n-blue-4 text-n-blue-11"
              >
                {{
                  t(
                    'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.SELECTED',
                    {
                      count: selectedTemplateColumns.length,
                    }
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
                    'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.STANDARD'
                  )
                }}
              </p>
              <div class="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
                <label
                  v-for="column in standardTemplateColumns"
                  :key="column.value"
                  class="flex items-center gap-3 px-3 py-2.5 transition-all border rounded-lg cursor-pointer"
                  :class="
                    selectedTemplateColumns.includes(column.value)
                      ? 'border-n-brand/40 bg-n-brand/5 shadow-sm'
                      : 'border-n-weak bg-n-background hover:bg-n-alpha-1'
                  "
                >
                  <span
                    class="flex items-center justify-center rounded-md size-7 transition-colors"
                    :class="
                      selectedTemplateColumns.includes(column.value)
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
                    :model-value="
                      selectedTemplateColumns.includes(column.value)
                    "
                    @change="
                      event =>
                        toggleTemplateColumn(column.value, event.target.checked)
                    "
                  />
                </label>
              </div>
            </div>
            <div
              v-if="customTemplateColumns.length"
              class="pt-3 border-t border-n-weak"
            >
              <p
                class="mb-2 text-xs font-semibold uppercase tracking-wide text-n-slate-9"
              >
                {{
                  t(
                    'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.COLUMNS.CUSTOM'
                  )
                }}
              </p>
              <div class="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
                <label
                  v-for="column in customTemplateColumns"
                  :key="column.value"
                  class="flex items-center gap-3 px-3 py-2.5 transition-all border rounded-lg cursor-pointer"
                  :class="
                    selectedTemplateColumns.includes(column.value)
                      ? 'border-n-brand/40 bg-n-brand/5 shadow-sm'
                      : 'border-n-weak bg-n-background hover:bg-n-alpha-1'
                  "
                >
                  <span
                    class="flex items-center justify-center rounded-md size-7 transition-colors"
                    :class="
                      selectedTemplateColumns.includes(column.value)
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
                    :model-value="
                      selectedTemplateColumns.includes(column.value)
                    "
                    @change="
                      event =>
                        toggleTemplateColumn(column.value, event.target.checked)
                    "
                  />
                </label>
              </div>
            </div>
          </div>

          <div
            class="flex items-center justify-between gap-3 p-3 mt-4 border rounded-lg border-n-weak bg-n-background"
          >
            <div
              class="flex items-center min-w-0 gap-2 text-sm text-n-slate-11"
            >
              <span class="i-lucide-file-spreadsheet size-4 text-n-blue-11" />
              <span class="truncate">
                {{
                  t(
                    'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.TEMPLATE.HINT'
                  )
                }}
              </span>
            </div>
            <Button
              :label="
                t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.TEMPLATE.DOWNLOAD'
                )
              "
              icon="i-lucide-download"
              color="blue"
              variant="outline"
              size="sm"
              type="button"
              :is-loading="isDownloadingTemplate"
              :disabled="!hasTemplateColumns"
              class="shrink-0 !px-4"
              @click="downloadTemplate"
            />
          </div>
        </section>

        <section
          class="flex flex-col justify-between gap-4 p-4 border rounded-xl border-n-weak bg-n-alpha-1"
        >
          <div>
            <div
              class="flex items-center gap-2 text-base font-semibold text-n-slate-12"
            >
              <span class="i-lucide-shield-check size-5 text-n-teal-11" />
              {{
                t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.WORKBOOK.TITLE'
                )
              }}
            </div>
            <div class="mt-4 overflow-hidden border rounded-lg border-n-weak">
              <div
                v-for="check in workbookChecks"
                :key="check.label"
                class="flex items-center justify-between gap-3 px-3 py-3 text-sm border-b border-n-weak last:border-b-0"
              >
                <span class="font-medium text-n-slate-11">
                  {{ check.label }}
                </span>
                <span class="flex items-center gap-2 text-n-slate-12">
                  {{ check.value }}
                  <span
                    class="size-4"
                    :class="
                      check.isReady
                        ? 'i-lucide-check-circle-2 text-n-teal-11'
                        : 'i-lucide-circle text-n-slate-9'
                    "
                  />
                </span>
              </div>
            </div>
          </div>

          <div
            class="flex items-center gap-3 p-3 text-sm border rounded-lg"
            :class="
              isExcelFile
                ? 'border-n-teal-5 bg-n-teal-3 text-n-teal-12'
                : 'border-n-weak bg-n-background text-n-slate-11'
            "
          >
            <span
              class="flex items-center justify-center rounded-full size-9 bg-n-background"
            >
              <span
                class="size-5"
                :class="
                  isExcelFile
                    ? 'i-lucide-check text-n-teal-11'
                    : 'i-lucide-file-check-2 text-n-slate-10'
                "
              />
            </span>
            <div>
              <div class="font-semibold">
                {{
                  isExcelFile
                    ? t(
                        'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHECKS.READY'
                      )
                    : t(
                        'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHECKS.WAITING'
                      )
                }}
              </div>
              <div class="text-xs opacity-80">
                {{
                  t(
                    'CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHECKS.READY_HINT'
                  )
                }}
              </div>
            </div>
          </div>
        </section>
      </div>

      <section
        class="overflow-hidden border rounded-xl border-n-weak bg-n-alpha-1"
      >
        <div
          class="flex items-center justify-between gap-3 px-4 py-3 border-b border-n-weak"
        >
          <div
            class="flex items-center gap-2 text-sm font-semibold text-n-slate-12"
          >
            <span class="i-lucide-table-2 size-4 text-n-blue-11" />
            {{
              t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.PREVIEW.TITLE')
            }}
          </div>
          <span class="text-xs text-n-slate-11">
            {{ previewSubtitle }}
          </span>
        </div>
        <div
          v-if="previewError"
          class="px-4 py-3 text-sm border-b border-n-weak text-n-ruby-11"
        >
          {{ previewError }}
        </div>
        <div
          v-if="isPreviewingImport"
          class="flex items-center justify-center gap-2 px-4 py-10 text-sm text-n-slate-11"
        >
          <span class="i-lucide-loader-circle animate-spin size-4" />
          {{
            t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.PREVIEW.LOADING')
          }}
        </div>
        <div
          v-else-if="previewTableHeaders.length"
          class="overflow-x-auto bg-n-background"
        >
          <table class="w-max min-w-full text-sm border-collapse">
            <thead class="bg-n-alpha-1 text-n-slate-11">
              <tr>
                <th
                  v-for="column in previewColumns"
                  :key="column.key"
                  class="px-4 py-3 font-semibold align-middle border-b border-n-weak text-start"
                  :class="column.classes"
                >
                  <span class="block truncate">
                    {{ column.label }}
                  </span>
                  <span
                    v-if="column.description"
                    dir="ltr"
                    class="block mt-0.5 text-xs font-normal truncate text-n-slate-10"
                  >
                    {{ column.description }}
                  </span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="(row, rowIndex) in previewTableRows"
                :key="rowIndex"
                class="text-n-slate-11"
              >
                <td
                  v-for="(column, cellIndex) in previewColumns"
                  :key="`${rowIndex}-${cellIndex}`"
                  class="px-4 py-3 align-middle border-b border-n-weak text-n-slate-11"
                  :class="[column.classes, previewCellClass(column)]"
                  :dir="column.direction"
                >
                  <span class="block truncate">
                    {{ previewCellValue(row, cellIndex) }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-else class="px-4 py-10 text-sm text-center text-n-slate-11">
          {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.PREVIEW.EMPTY') }}
        </div>
      </section>

      <div
        v-if="isImportingContact"
        class="flex items-center gap-3 px-4 py-3 text-sm border rounded-xl border-n-blue-5 bg-n-blue-3 text-n-blue-12"
      >
        <span class="i-lucide-loader-circle animate-spin size-4" />
        <span>
          {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.PROGRESS') }}
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
          :label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.IMPORT')"
          icon="i-lucide-upload"
          trailing-icon
          color="blue"
          size="lg"
          type="button"
          class="w-full sm:w-64"
          :is-loading="isImportingContact"
          :disabled="disableImport"
          @click="uploadFile"
        />
      </div>
    </template>

    <input
      ref="fileInput"
      type="file"
      accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      class="hidden"
      @change="handleFileChange"
    />
  </Dialog>
</template>
