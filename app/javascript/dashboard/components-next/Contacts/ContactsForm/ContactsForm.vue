<script setup>
import { computed, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { required, email as emailValidator } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';

import Input from 'dashboard/components-next/input/Input.vue';
import AddressSelect from './AddressSelect.vue';
import { EGYPT_GOVERNORATES } from 'dashboard/constants/egyptGovernorates';
import { EGYPT_DISTRICTS } from 'dashboard/constants/egyptDistricts';
import { getClassificationCardActiveClass } from 'dashboard/helper/contactsClassificationColors';

const props = defineProps({
  contactData: {
    type: Object,
    default: null,
  },
  isDetailsView: {
    type: Boolean,
    default: false,
  },
  isNewContact: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update']);
const { t } = useI18n();

const classificationOptions = computed(() => [
  {
    label: t(
      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.LIBRARY'
    ),
    value: 'Library',
  },
  {
    label: t(
      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.TEACHER'
    ),
    value: 'Teacher',
  },
  {
    label: t(
      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.STUDENT'
    ),
    value: 'Student',
  },
  {
    label: t(
      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.CENTER'
    ),
    value: 'Center',
  },
  {
    label: t(
      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.OTHER'
    ),
    value: 'Other',
  },
]);

const libraryClassificationOptions = computed(() => [
  {
    label: t(
      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.LIBRARY_CLASSIFICATION_OPTIONS.SECTOR'
    ),
    value: 'قطاعي',
  },
  {
    label: t(
      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.LIBRARY_CLASSIFICATION_OPTIONS.WHOLESALE'
    ),
    value: 'جملة',
  },
]);

const phoneTypeOptions = ['Mobile', 'Landline', 'Other'];

const classificationCardActiveClass = getClassificationCardActiveClass;

const defaultPhoneRow = () => ({
  mobileOwner: '',
  phoneType: 'Mobile',
  phone: '',
  whatsapp: true,
  telegram: false,
  defaultPhone: false,
});

const defaultAddressRow = () => ({
  governorate: '',
  district: '',
  neighborhood: '',
  street: '',
  locationUrl: '',
  primary: false,
});

const state = reactive({
  id: 0,
  name: '',
  email: '',
  identifier: '',
  phoneNumber: '',
  additionalAttributes: {
    customCustomerClassification: '',
    customCustomerClassificationOther: '',
    customLibraryClassification: '',
    customCustomerMobileNumbers: [],
    customAddresses: [],
    currentCustomerDiscount: '',
    erpLinkStatus: '',
    erpLastSyncedAt: '',
    erpSyncError: '',
  },
});

const mobileOwnerOptions = computed(() => {
  const base =
    'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.PHONE_TABLE.MOBILE_OWNER_OPTIONS';
  switch (state.additionalAttributes.customCustomerClassification) {
    case 'Library':
      return [
        { label: t(`${base}.LIBRARY.CONTACT`), value: 'Library Contact' },
        { label: t(`${base}.LIBRARY.EMPLOYEE`), value: 'Employee Number' },
        { label: t(`${base}.LIBRARY.OWNER`), value: 'Library Owner Number' },
      ];
    case 'Teacher':
      return [
        { label: t(`${base}.TEACHER.TEACHER`), value: 'Teacher Number' },
        { label: t(`${base}.TEACHER.SECRETARY`), value: 'Secretary Number' },
        { label: t(`${base}.TEACHER.CENTER`), value: 'Center Number' },
      ];
    case 'Student':
      return [
        { label: t(`${base}.STUDENT.STUDENT`), value: 'Student Number' },
        { label: t(`${base}.STUDENT.PARENT`), value: 'Parent Number' },
      ];
    case 'Center':
      return [{ label: t(`${base}.CENTER.CENTER`), value: 'Center Number' }];
    default:
      return [];
  }
});

const validationRules = { name: { required }, email: { emailValidator } };
const v$ = useVuelidate(validationRules, state);

const phoneLimitFor = type => {
  if (type === 'Mobile') return 11;
  if (type === 'Landline') return 10;
  return Infinity;
};
const phoneMinFor = type => {
  if (type === 'Mobile') return 11;
  if (type === 'Landline') return 9;
  return 0;
};

const hasInvalidPhones = computed(() =>
  state.additionalAttributes.customCustomerMobileNumbers.some(
    row =>
      row.phone &&
      row.phone.replace(/\D/g, '').length < phoneMinFor(row.phoneType)
  )
);

const isFormInvalid = computed(
  () => v$.value.$invalid || hasInvalidPhones.value
);

const showClassificationOther = computed(
  () => state.additionalAttributes.customCustomerClassification === 'Other'
);

const showLibraryClassification = computed(
  () => state.additionalAttributes.customCustomerClassification === 'Library'
);

const normalizePhone = phone => {
  if (!phone || phone.startsWith('+')) return phone;
  if (/^0\d+$/.test(phone)) return `+20${phone.slice(1)}`;
  return phone;
};

const migratePhones = (attrs, mainPhoneNumber) => {
  if (
    Array.isArray(attrs.customCustomerMobileNumbers) &&
    attrs.customCustomerMobileNumbers.length > 0
  )
    return attrs.customCustomerMobileNumbers.map(r => ({
      ...defaultPhoneRow(),
      ...r,
      phone: normalizePhone(r.phone),
    }));

  const phones = [];
  if (attrs.phoneSecondary)
    phones.push({
      ...defaultPhoneRow(),
      phone: normalizePhone(attrs.phoneSecondary),
    });
  if (attrs.phoneAlternative)
    phones.push({
      ...defaultPhoneRow(),
      phone: normalizePhone(attrs.phoneAlternative),
    });
  if (phones.length === 0 && mainPhoneNumber)
    phones.push({
      ...defaultPhoneRow(),
      phone: normalizePhone(mainPhoneNumber),
      defaultPhone: true,
    });
  return phones;
};

const migrateAddresses = attrs => {
  if (Array.isArray(attrs.customAddresses) && attrs.customAddresses.length > 0)
    return attrs.customAddresses.map(r => ({ ...defaultAddressRow(), ...r }));

  if (
    attrs.addressGovernorate ||
    attrs.addressDistrict ||
    attrs.addressNeighborhood ||
    attrs.addressStreet ||
    attrs.locationUrl
  )
    return [
      {
        governorate: attrs.addressGovernorate || '',
        district: attrs.addressDistrict || '',
        neighborhood: attrs.addressNeighborhood || '',
        street: attrs.addressStreet || '',
        locationUrl: attrs.locationUrl || '',
        primary: true,
      },
    ];

  return [];
};

const prepareStateBasedOnProps = () => {
  if (props.isNewContact) return;

  const {
    id,
    name = '',
    email: emailAddress = '',
    identifier = '',
    phoneNumber,
    additionalAttributes = {},
  } = props.contactData || {};

  const {
    customCustomerClassification = '',
    customCustomerClassificationOther = '',
    customLibraryClassification = '',
    currentCustomerDiscount = '',
    erpLinkStatus = '',
    erpLastSyncedAt = '',
    erpSyncError = '',
  } = additionalAttributes || {};

  Object.assign(state, {
    id,
    name,
    email: emailAddress,
    identifier,
    phoneNumber: phoneNumber || '',
    additionalAttributes: {
      customCustomerClassification,
      customCustomerClassificationOther,
      customLibraryClassification,
      customCustomerMobileNumbers: migratePhones(
        additionalAttributes || {},
        phoneNumber
      ),
      customAddresses: migrateAddresses(additionalAttributes || {}),
      currentCustomerDiscount,
      erpLinkStatus,
      erpLastSyncedAt,
      erpSyncError,
    },
  });
};

const syncPhoneNumber = () => {
  const numbers = state.additionalAttributes.customCustomerMobileNumbers;
  const defaultRow = numbers.find(
    r => r.defaultPhone && r.phone?.startsWith('+')
  );
  const fallbackRow = defaultRow || numbers.find(r => r.phone?.startsWith('+'));
  state.phoneNumber = fallbackRow?.phone || '';
};

const emitUpdate = async () => {
  syncPhoneNumber();
  const isValid = await v$.value.$validate();
  if (isValid && !hasInvalidPhones.value) emit('update', state);
};

const handleClassificationChange = value => {
  const current = state.additionalAttributes.customCustomerClassification;
  const newValue = current === value ? '' : value;
  state.additionalAttributes.customCustomerClassification = newValue;
  if (newValue !== 'Other')
    state.additionalAttributes.customCustomerClassificationOther = '';
  if (newValue !== 'Library')
    state.additionalAttributes.customLibraryClassification = '';
  if (newValue !== current) {
    state.additionalAttributes.customCustomerMobileNumbers.forEach(row => {
      row.mobileOwner = '';
    });
  }
  emitUpdate();
};

const addPhoneRow = () => {
  const isFirst =
    state.additionalAttributes.customCustomerMobileNumbers.length === 0;
  state.additionalAttributes.customCustomerMobileNumbers.push({
    ...defaultPhoneRow(),
    defaultPhone: isFirst,
  });
  emitUpdate();
};

const removePhoneRow = idx => {
  state.additionalAttributes.customCustomerMobileNumbers.splice(idx, 1);
  emitUpdate();
};

const setDefaultPhone = idx => {
  state.additionalAttributes.customCustomerMobileNumbers.forEach((row, i) => {
    row.defaultPhone = i === idx;
  });
  emitUpdate();
};

const onGovernorateChange = row => {
  row.district = '';
  emitUpdate();
};

const addAddressRow = () => {
  state.additionalAttributes.customAddresses.push(defaultAddressRow());
  emitUpdate();
};

const removeAddressRow = idx => {
  state.additionalAttributes.customAddresses.splice(idx, 1);
  emitUpdate();
};

const setPrimaryAddress = idx => {
  state.additionalAttributes.customAddresses.forEach((row, i) => {
    row.primary = i === idx;
  });
  emitUpdate();
};

const districtsFor = governorate =>
  EGYPT_DISTRICTS.filter(d => d.governorate === governorate);

const onPhoneInput = (row, event) => {
  const raw = event?.target?.value ?? row.phone;
  const digits = raw
    .replace(/[٠-٩]/g, d => d.charCodeAt(0) - 0x0660)
    .replace(/[^\d+]/g, '')
    .replace(/(?!^)\+/g, '');
  const limit = phoneLimitFor(row.phoneType);
  const normalized = digits.length > limit ? digits.slice(0, limit) : digits;
  row.phone = normalized;
  if (event?.target) event.target.value = normalized;
  emitUpdate();
};

const onPhoneBlur = (row, event) => {
  const val = row.phone.trim();
  if (!val || val.startsWith('+')) return;
  if (/^0\d+$/.test(val)) {
    const formatted = `+20${val.slice(1)}`;
    row.phone = formatted;
    if (event?.target) event.target.value = formatted;
    emitUpdate();
  }
};

const inputClass = computed(
  () =>
    `h-11 !pt-2 !pb-2 !text-base ${
      !props.isDetailsView ? '[&:not(.error,.focus)]:!outline-transparent' : ''
    }`
);

const cellInputClass = 'h-9 !pt-1.5 !pb-1.5 !text-sm';

const resetValidation = () => v$.value.$reset();

const resetForm = () => {
  Object.assign(state, {
    id: 0,
    name: '',
    email: '',
    identifier: '',
    phoneNumber: '',
    additionalAttributes: {
      customCustomerClassification: '',
      customCustomerClassificationOther: '',
      customLibraryClassification: '',
      customCustomerMobileNumbers: [],
      customAddresses: [],
      currentCustomerDiscount: '',
      erpLinkStatus: '',
      erpLastSyncedAt: '',
      erpSyncError: '',
    },
  });
};

watch(
  () => props.contactData?.id,
  id => {
    if (id) prepareStateBasedOnProps();
  },
  { immediate: true }
);

defineExpose({ state, resetValidation, isFormInvalid, resetForm });
</script>

<template>
  <div class="flex flex-col gap-6">
    <!-- Name + Email (2-column) -->
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
      <div class="flex flex-col gap-2">
        <span
          class="flex items-center gap-2 text-sm font-semibold text-n-slate-12"
        >
          <span class="i-lucide-user size-4" />
          {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.NAME_LABEL') }}
        </span>
        <Input
          v-model="state.name"
          :placeholder="
            t(
              'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CUSTOMER_NAME.PLACEHOLDER'
            )
          "
          :message-type="v$.name.$error ? 'error' : 'info'"
          :custom-input-class="inputClass"
          class="w-full"
          @input="
            v$.name.$touch();
            emitUpdate();
          "
          @blur="v$.name.$touch()"
        />
      </div>
      <div class="flex flex-col gap-2">
        <span
          class="flex items-center gap-2 text-sm font-semibold text-n-slate-12"
        >
          <span class="i-lucide-mail size-4" />
          {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.EMAIL_LABEL') }}
        </span>
        <Input
          v-model="state.email"
          :placeholder="
            t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.EMAIL.PLACEHOLDER')
          "
          :message-type="v$.email.$error ? 'error' : 'info'"
          :custom-input-class="inputClass"
          class="w-full"
          @input="
            v$.email.$touch();
            emitUpdate();
          "
          @blur="v$.email.$touch()"
        />
      </div>
    </div>

    <!-- ERP Code (right column only) -->
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
      <div class="flex flex-col gap-2 sm:col-start-2">
        <span
          class="flex items-center gap-2 text-sm font-semibold text-n-slate-12"
        >
          <span class="i-lucide-hash size-4" />
          {{
            t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.IDENTIFIER_LABEL')
          }}
        </span>
        <Input
          v-model="state.identifier"
          dir="ltr"
          placeholder="CUST-12345"
          :custom-input-class="inputClass"
          :disabled="!isNewContact"
          class="w-full"
          @input="emitUpdate()"
        />
      </div>
    </div>

    <!-- Classification -->
    <div class="flex flex-col gap-3">
      <span class="text-sm font-semibold text-n-slate-12">
        {{
          t(
            'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CUSTOMER_CLASSIFICATION.LABEL'
          )
        }}
      </span>
      <div class="grid grid-cols-5 gap-3">
        <button
          v-for="option in classificationOptions"
          :key="option.value"
          type="button"
          class="flex flex-col items-center gap-2 px-3 py-4 text-sm font-semibold transition-colors border rounded-xl"
          :class="
            state.additionalAttributes.customCustomerClassification ===
            option.value
              ? classificationCardActiveClass(option.value)
              : 'border-n-weak bg-n-background text-n-slate-11 hover:bg-n-alpha-2'
          "
          @click="handleClassificationChange(option.value)"
        >
          <span
            class="size-6"
            :class="[
              option.value === 'Library' && 'i-lucide-library',
              option.value === 'Teacher' && 'i-lucide-graduation-cap',
              option.value === 'Student' && 'i-lucide-user',
              option.value === 'Center' && 'i-lucide-building-2',
              option.value === 'Other' && 'i-lucide-ellipsis',
            ]"
          />
          {{ option.label }}
        </button>
      </div>
      <Input
        v-if="showClassificationOther"
        v-model="state.additionalAttributes.customCustomerClassificationOther"
        :placeholder="
          t(
            'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OTHER.PLACEHOLDER'
          )
        "
        :custom-input-class="inputClass"
        class="w-full"
        @input="emitUpdate()"
      />
      <div v-if="showLibraryClassification" class="flex flex-col gap-2">
        <span class="text-xs text-n-slate-10">
          {{
            t(
              'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.LIBRARY_CLASSIFICATION.LABEL'
            )
          }}
        </span>
        <div class="grid grid-cols-2 gap-2">
          <button
            v-for="option in libraryClassificationOptions"
            :key="option.value"
            type="button"
            class="flex items-center justify-center px-3 py-2 text-sm font-medium transition-colors border rounded-lg"
            :class="
              state.additionalAttributes.customLibraryClassification ===
              option.value
                ? 'border-n-brand/40 bg-n-brand/10 text-n-blue-11'
                : 'border-n-weak bg-n-background text-n-slate-11 hover:bg-n-alpha-2'
            "
            @click="
              () => {
                state.additionalAttributes.customLibraryClassification =
                  option.value;
                emitUpdate();
              }
            "
          >
            {{ option.label }}
          </button>
        </div>
      </div>
    </div>

    <!-- Phone Numbers -->
    <div
      class="flex flex-col gap-4 p-5 rounded-xl border border-n-weak bg-n-alpha-1"
    >
      <div
        v-if="
          state.additionalAttributes.customCustomerMobileNumbers.length === 0
        "
        class="flex flex-col items-center gap-4 py-5 text-center"
      >
        <div
          class="flex items-center justify-center rounded-full size-14 bg-n-brand/10"
        >
          <span class="i-lucide-phone size-6 text-n-brand" />
        </div>
        <div class="space-y-1">
          <p class="text-base font-bold text-n-slate-12">
            {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SECTIONS.PHONES') }}
          </p>
          <p class="text-sm text-n-slate-10">
            {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.PHONE_TABLE.EMPTY') }}
          </p>
        </div>
        <button
          type="button"
          class="flex items-center gap-2 px-5 py-2 text-sm font-semibold rounded-lg border border-n-brand/30 text-n-blue-11 bg-n-brand/5 hover:bg-n-brand/10 transition-colors"
          @click="addPhoneRow"
        >
          <span class="i-lucide-plus size-4" />
          {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.PHONE_TABLE.ADD_ROW') }}
        </button>
      </div>
      <template v-else>
        <div class="flex items-center justify-between">
          <span class="text-base font-bold text-n-slate-12">
            {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SECTIONS.PHONES') }}
          </span>
          <button
            type="button"
            class="flex items-center gap-1.5 px-3 py-1.5 text-sm font-semibold rounded-lg text-n-blue-11 hover:bg-n-alpha-2"
            @click="addPhoneRow"
          >
            <span class="i-lucide-plus size-4" />
            {{
              t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.PHONE_TABLE.ADD_ROW')
            }}
          </button>
        </div>

        <div class="flex flex-col gap-3">
          <div
            v-for="(row, idx) in state.additionalAttributes
              .customCustomerMobileNumbers"
            :key="idx"
            class="rounded-xl border bg-n-solid-1 p-4 transition-colors"
            :class="
              row.defaultPhone
                ? 'border-n-brand/40 ring-1 ring-n-brand/20'
                : 'border-n-weak'
            "
          >
            <!-- Card header: index + default badge + delete -->
            <div class="flex items-center justify-between mb-3">
              <div class="flex items-center gap-2">
                <span
                  class="flex items-center justify-center size-7 rounded-md bg-n-brand/10 text-n-brand text-sm font-bold tabular-nums"
                >
                  {{ idx + 1 }}
                </span>
                <span class="text-sm font-semibold text-n-slate-12">
                  {{
                    t(
                      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.PHONE_TABLE.PHONE'
                    )
                  }}
                </span>
                <span
                  v-if="row.defaultPhone"
                  class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-xs font-semibold bg-n-brand/10 text-n-blue-11"
                >
                  <span class="i-lucide-star size-3" />
                  {{
                    t(
                      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.PHONE_TABLE.DEFAULT'
                    )
                  }}
                </span>
              </div>
              <div class="flex items-center gap-1">
                <button
                  v-if="!row.defaultPhone"
                  type="button"
                  class="text-xs font-medium px-2 py-1 rounded-md text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
                  @click="setDefaultPhone(idx)"
                >
                  {{
                    t(
                      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.PHONE_TABLE.DEFAULT'
                    )
                  }}
                </button>
                <button
                  type="button"
                  class="flex items-center justify-center size-7 rounded-md text-n-slate-10 hover:bg-n-ruby-3 hover:text-n-ruby-11 transition-colors"
                  @click="removePhoneRow(idx)"
                >
                  <span class="i-ph-trash size-4" />
                </button>
              </div>
            </div>

            <!-- Field grid: phone (8) + type (4) -->
            <div class="grid grid-cols-12 gap-3 mb-3">
              <div class="col-span-12 sm:col-span-8 flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-11">
                  {{
                    t(
                      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.PHONE_TABLE.PHONE'
                    )
                  }}
                </label>
                <Input
                  v-model="row.phone"
                  dir="ltr"
                  inputmode="numeric"
                  :custom-input-class="cellInputClass"
                  class="w-full"
                  @input="onPhoneInput(row, $event)"
                  @blur="onPhoneBlur(row, $event)"
                />
              </div>
              <div class="col-span-12 sm:col-span-4 flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-11">
                  {{
                    t(
                      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.PHONE_TABLE.PHONE_TYPE'
                    )
                  }}
                </label>
                <select
                  v-model="row.phoneType"
                  class="!mb-0 h-9 w-full rounded-lg border border-n-weak bg-n-alpha-black2 px-2.5 text-sm text-n-slate-12 focus:outline-none focus:border-n-brand"
                  @change="emitUpdate()"
                >
                  <option
                    v-for="opt in phoneTypeOptions"
                    :key="opt"
                    :value="opt"
                  >
                    {{ opt }}
                  </option>
                </select>
              </div>
            </div>

            <!-- Mobile owner full width -->
            <div class="flex flex-col gap-1.5 mb-3">
              <label class="text-xs font-semibold text-n-slate-11">
                {{
                  t(
                    'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.PHONE_TABLE.MOBILE_OWNER'
                  )
                }}
              </label>
              <select
                v-if="mobileOwnerOptions.length > 0"
                v-model="row.mobileOwner"
                class="!mb-0 h-9 w-full rounded-lg border border-n-weak bg-n-alpha-black2 px-2.5 text-sm text-n-slate-12 focus:outline-none focus:border-n-brand"
                @change="emitUpdate()"
              >
                <option value="">
                  {{
                    t(
                      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.PHONE_TABLE.MOBILE_OWNER_OPTIONS.PLACEHOLDER'
                    )
                  }}
                </option>
                <option
                  v-for="opt in mobileOwnerOptions"
                  :key="opt.value"
                  :value="opt.value"
                >
                  {{ opt.label }}
                </option>
              </select>
              <Input
                v-else
                v-model="row.mobileOwner"
                :custom-input-class="cellInputClass"
                class="w-full"
                @input="emitUpdate()"
              />
            </div>

            <!-- Channel toggles -->
            <div class="flex items-center gap-2 pt-3 border-t border-n-weak">
              <label
                class="flex items-center gap-2 px-3 py-1.5 rounded-lg border cursor-pointer transition-colors"
                :class="
                  row.whatsapp
                    ? 'border-n-teal-7 bg-n-teal-3 text-n-teal-11'
                    : 'border-n-weak bg-n-alpha-1 text-n-slate-11 hover:bg-n-alpha-2'
                "
              >
                <input
                  v-model="row.whatsapp"
                  type="checkbox"
                  class="rounded border-n-weak accent-n-teal-10 size-4 cursor-pointer"
                  @change="emitUpdate()"
                />
                <span class="text-sm font-semibold">{{ 'WhatsApp' }}</span>
              </label>
              <label
                class="flex items-center gap-2 px-3 py-1.5 rounded-lg border cursor-pointer transition-colors"
                :class="
                  row.telegram
                    ? 'border-n-blue-7 bg-n-blue-3 text-n-blue-11'
                    : 'border-n-weak bg-n-alpha-1 text-n-slate-11 hover:bg-n-alpha-2'
                "
              >
                <input
                  v-model="row.telegram"
                  type="checkbox"
                  class="rounded border-n-weak accent-n-blue-10 size-4 cursor-pointer"
                  @change="emitUpdate()"
                />
                <span class="text-sm font-semibold">{{ 'Telegram' }}</span>
              </label>
            </div>
          </div>
        </div>
      </template>
    </div>

    <!-- Addresses -->
    <div
      class="flex flex-col gap-4 p-5 rounded-xl border border-n-weak bg-n-alpha-1"
    >
      <div
        v-if="state.additionalAttributes.customAddresses.length === 0"
        class="flex flex-col items-center gap-4 py-5 text-center"
      >
        <div
          class="flex items-center justify-center rounded-full size-14 bg-n-brand/10"
        >
          <span class="i-lucide-map-pin size-6 text-n-brand" />
        </div>
        <div class="space-y-1">
          <p class="text-base font-bold text-n-slate-12">
            {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SECTIONS.ADDRESS') }}
          </p>
          <p class="text-sm text-n-slate-10">
            {{
              t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ADDRESS_TABLE.EMPTY')
            }}
          </p>
        </div>
        <button
          type="button"
          class="flex items-center gap-2 px-5 py-2 text-sm font-semibold rounded-lg border border-n-brand/30 text-n-blue-11 bg-n-brand/5 hover:bg-n-brand/10 transition-colors"
          @click="addAddressRow"
        >
          <span class="i-lucide-plus size-4" />
          {{
            t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ADDRESS_TABLE.ADD_ROW')
          }}
        </button>
      </div>
      <template v-else>
        <div class="flex items-center justify-between">
          <span class="text-base font-bold text-n-slate-12">
            {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SECTIONS.ADDRESS') }}
          </span>
          <button
            type="button"
            class="flex items-center gap-1.5 px-3 py-1.5 text-sm font-semibold rounded-lg text-n-blue-11 hover:bg-n-alpha-2"
            @click="addAddressRow"
          >
            <span class="i-lucide-plus size-4" />
            {{
              t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ADDRESS_TABLE.ADD_ROW')
            }}
          </button>
        </div>
        <div class="flex flex-col gap-3">
          <div
            v-for="(row, idx) in state.additionalAttributes.customAddresses"
            :key="idx"
            class="rounded-xl border bg-n-solid-1 p-4 transition-colors"
            :class="
              row.primary
                ? 'border-n-brand/40 ring-1 ring-n-brand/20'
                : 'border-n-weak'
            "
          >
            <!-- Card header -->
            <div class="flex items-center justify-between mb-3">
              <div class="flex items-center gap-2">
                <span
                  class="flex items-center justify-center size-7 rounded-md bg-n-brand/10 text-n-brand text-sm font-bold tabular-nums"
                >
                  {{ idx + 1 }}
                </span>
                <span class="text-sm font-semibold text-n-slate-12">
                  {{
                    t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SECTIONS.ADDRESS')
                  }}
                </span>
                <span
                  v-if="row.primary"
                  class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-xs font-semibold bg-n-brand/10 text-n-blue-11"
                >
                  <span class="i-lucide-star size-3" />
                  {{
                    t(
                      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ADDRESS_TABLE.PRIMARY'
                    )
                  }}
                </span>
              </div>
              <div class="flex items-center gap-1">
                <button
                  v-if="!row.primary"
                  type="button"
                  class="text-xs font-medium px-2 py-1 rounded-md text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
                  @click="setPrimaryAddress(idx)"
                >
                  {{
                    t(
                      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ADDRESS_TABLE.PRIMARY'
                    )
                  }}
                </button>
                <button
                  type="button"
                  class="flex items-center justify-center size-7 rounded-md text-n-slate-10 hover:bg-n-ruby-3 hover:text-n-ruby-11 transition-colors"
                  @click="removeAddressRow(idx)"
                >
                  <span class="i-ph-trash size-4" />
                </button>
              </div>
            </div>

            <!-- Governorate + District -->
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-3">
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-11">
                  {{
                    t(
                      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ADDRESS_TABLE.GOVERNORATE'
                    )
                  }}
                </label>
                <AddressSelect
                  v-model="row.governorate"
                  :options="EGYPT_GOVERNORATES"
                  :placeholder="
                    t(
                      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ADDRESS_TABLE.GOVERNORATE'
                    )
                  "
                  @change="onGovernorateChange(row)"
                />
              </div>
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-11">
                  {{
                    t(
                      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ADDRESS_TABLE.DISTRICT'
                    )
                  }}
                </label>
                <AddressSelect
                  v-if="districtsFor(row.governorate).length > 0"
                  v-model="row.district"
                  :options="districtsFor(row.governorate)"
                  :placeholder="
                    t(
                      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ADDRESS_TABLE.DISTRICT'
                    )
                  "
                  @change="emitUpdate()"
                />
                <Input
                  v-else
                  v-model="row.district"
                  :custom-input-class="cellInputClass"
                  class="w-full"
                  @input="emitUpdate()"
                />
              </div>
            </div>

            <!-- Neighborhood + Street -->
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-3">
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-11">
                  {{
                    t(
                      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ADDRESS_TABLE.NEIGHBORHOOD'
                    )
                  }}
                </label>
                <Input
                  v-model="row.neighborhood"
                  :custom-input-class="cellInputClass"
                  class="w-full"
                  @input="emitUpdate()"
                />
              </div>
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-11">
                  {{
                    t(
                      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ADDRESS_TABLE.STREET'
                    )
                  }}
                </label>
                <Input
                  v-model="row.street"
                  :custom-input-class="cellInputClass"
                  class="w-full"
                  @input="emitUpdate()"
                />
              </div>
            </div>

            <!-- Location URL full width -->
            <div class="flex flex-col gap-1.5">
              <label
                class="flex items-center gap-1.5 text-xs font-semibold text-n-slate-11"
              >
                <span class="i-lucide-map-pin size-3.5" />
                {{
                  t(
                    'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ADDRESS_TABLE.LOCATION_URL'
                  )
                }}
              </label>
              <Input
                v-model="row.locationUrl"
                dir="ltr"
                :custom-input-class="cellInputClass"
                class="w-full"
                @input="emitUpdate()"
              />
            </div>
          </div>
        </div>
      </template>
    </div>

    <!-- Business Info (read-only, only shown if discount exists) -->
    <div
      v-if="state.additionalAttributes.currentCustomerDiscount"
      class="flex items-center justify-between gap-3 px-3 py-3 rounded-lg border border-n-weak bg-n-alpha-2"
    >
      <span class="text-sm text-n-slate-11">
        {{
          t(
            'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CUSTOMER_DISCOUNT.LABEL'
          )
        }}
      </span>
      <span class="text-sm font-semibold text-n-slate-12" dir="ltr">
        {{ state.additionalAttributes.currentCustomerDiscount }}
      </span>
    </div>
  </div>
</template>
