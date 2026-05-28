<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import ContactsForm from 'dashboard/components-next/Contacts/ContactsForm/ContactsForm.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import ContactDeleteSection from 'dashboard/components-next/Contacts/ContactsCard/ContactDeleteSection.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import { getClassificationBadgeClass } from 'dashboard/helper/contactsClassificationColors';

const props = defineProps({
  id: { type: Number, required: true },
  name: { type: String, default: '' },
  email: { type: String, default: '' },
  additionalAttributes: { type: Object, default: () => ({}) },
  phoneNumber: { type: String, default: '' },
  thumbnail: { type: String, default: '' },
  availabilityStatus: { type: String, default: null },
  isExpanded: { type: Boolean, default: false },
  isUpdating: { type: Boolean, default: false },
  selectable: { type: Boolean, default: false },
  isSelected: { type: Boolean, default: false },
});

const emit = defineEmits([
  'toggle',
  'updateContact',
  'showContact',
  'select',
  'avatarHover',
]);

const { t } = useI18n();

const contactsFormRef = ref(null);

const getInitialContactData = () => ({
  id: props.id,
  name: props.name,
  email: props.email,
  phoneNumber: props.phoneNumber,
  additionalAttributes: props.additionalAttributes,
});

const contactData = ref(getInitialContactData());

const isFormInvalid = computed(() => contactsFormRef.value?.isFormInvalid);

const erpLinkStatus = computed(
  () => props.additionalAttributes?.erpLinkStatus || 'unlinked'
);

const erpStatusConfig = computed(() => {
  const map = {
    linked: {
      label: t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ERP_STATUS.LINKED'),
      class: 'bg-n-teal-3 text-n-teal-11',
    },
    sync_required: {
      label: t(
        'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ERP_STATUS.SYNC_REQUIRED'
      ),
      class: 'bg-n-amber-3 text-n-amber-11',
    },
    sync_failed: {
      label: t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ERP_STATUS.SYNC_FAILED'),
      class: 'bg-n-ruby-3 text-n-ruby-11',
    },
  };
  return (
    map[erpLinkStatus.value] || {
      label: t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ERP_STATUS.UNLINKED'),
      class: 'bg-n-alpha-2 text-n-slate-10',
    }
  );
});

const customerClassification = computed(
  () => props.additionalAttributes?.customCustomerClassification || ''
);

const classificationBadgeClass = getClassificationBadgeClass;

const handleFormUpdate = updatedData => {
  Object.assign(contactData.value, updatedData);
};

const handleUpdateContact = () => {
  emit('updateContact', contactData.value);
};

const onClickExpand = () => {
  emit('toggle');
  contactData.value = getInitialContactData();
};

const onClickViewDetails = () => emit('showContact', props.id);

const toggleSelect = checked => {
  emit('select', checked);
};

const handleAvatarHover = isHovered => {
  emit('avatarHover', isHovered);
};
</script>

<template>
  <div class="relative">
    <CardLayout
      :key="id"
      layout="row"
      :class="{
        'outline-n-weak !bg-n-slate-3 dark:!bg-n-solid-3': isSelected,
      }"
    >
      <div class="flex items-center justify-start flex-1 min-w-0 gap-3">
        <div
          class="relative shrink-0"
          @mouseenter="handleAvatarHover(true)"
          @mouseleave="handleAvatarHover(false)"
        >
          <Avatar
            :name="name"
            :src="thumbnail"
            :size="36"
            :status="availabilityStatus"
            hide-offline-status
            rounded-full
          >
            <template v-if="selectable" #overlay="{ size }">
              <label
                class="flex items-center justify-center rounded-full cursor-pointer absolute inset-0 z-10 backdrop-blur-[2px] border border-n-weak"
                :style="{ width: `${size}px`, height: `${size}px` }"
                @click.stop
              >
                <Checkbox
                  :model-value="isSelected"
                  @change="event => toggleSelect(event.target.checked)"
                />
              </label>
            </template>
          </Avatar>
        </div>

        <div class="flex flex-col gap-1 flex-1 min-w-0">
          <!-- Row 1: Name + badges -->
          <div class="flex flex-wrap items-center gap-1.5">
            <span
              dir="auto"
              class="min-w-0 text-sm font-semibold truncate text-start text-n-slate-12"
            >
              {{ name }}
            </span>
            <span
              class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium"
              :class="erpStatusConfig.class"
            >
              {{ erpStatusConfig.label }}
            </span>
            <span
              v-if="customerClassification"
              class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium"
              :class="classificationBadgeClass(customerClassification)"
            >
              {{ customerClassification }}
            </span>
          </div>

          <!-- Row 2: Contact info -->
          <div class="flex flex-wrap items-center gap-x-3 gap-y-0.5">
            <span
              v-if="email"
              dir="auto"
              class="flex items-center gap-1 text-xs text-n-slate-10 truncate max-w-64"
              :title="email"
            >
              <span class="i-lucide-mail size-3 shrink-0" />
              {{ email }}
            </span>
            <span
              v-if="phoneNumber"
              dir="ltr"
              class="flex items-center gap-1 text-xs font-mono text-n-slate-10 tabular-nums"
            >
              <span class="i-lucide-phone size-3 shrink-0" />
              {{ phoneNumber }}
            </span>
            <Button
              :label="t('CONTACTS_LAYOUT.CARD.VIEW_DETAILS')"
              variant="link"
              size="xs"
              class="!text-xs"
              @click="onClickViewDetails"
            />
          </div>
        </div>
      </div>

      <Button
        icon="i-lucide-chevron-down"
        variant="ghost"
        color="slate"
        size="xs"
        :class="{ 'rotate-180': isExpanded }"
        @click="onClickExpand"
      />

      <template #after>
        <div
          class="transition-all duration-500 ease-in-out grid overflow-hidden"
          :class="
            isExpanded
              ? 'grid-rows-[1fr] opacity-100'
              : 'grid-rows-[0fr] opacity-0'
          "
        >
          <div class="overflow-hidden">
            <div class="flex flex-col gap-5 p-4 border-t border-n-strong">
              <ContactsForm
                ref="contactsFormRef"
                :contact-data="contactData"
                @update="handleFormUpdate"
              />
              <div>
                <Button
                  :label="
                    t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.UPDATE_BUTTON')
                  "
                  size="sm"
                  :is-loading="isUpdating"
                  :disabled="isUpdating || isFormInvalid"
                  @click="handleUpdateContact"
                />
              </div>
            </div>
            <ContactDeleteSection
              :selected-contact="{
                id: props.id,
                name: props.name,
              }"
            />
          </div>
        </div>
      </template>
    </CardLayout>
  </div>
</template>
