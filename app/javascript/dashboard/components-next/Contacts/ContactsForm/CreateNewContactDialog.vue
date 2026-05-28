<script setup>
import { ref, computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ContactsForm from 'dashboard/components-next/Contacts/ContactsForm/ContactsForm.vue';

const emit = defineEmits(['create']);

const { t } = useI18n();

const dialogRef = ref(null);
const contactsFormRef = ref(null);
const contact = ref(null);

const uiFlags = useMapGetter('contacts/getUIFlags');
const isCreatingContact = computed(() => uiFlags.value.isCreating);

const createNewContact = contactItem => {
  contact.value = contactItem;
};

const handleDialogConfirm = async () => {
  if (!contact.value) return;
  emit('create', contact.value);
};

const onSuccess = () => {
  contactsFormRef.value?.resetForm();
  dialogRef.value.close();
};

const closeDialog = () => {
  dialogRef.value.close();
};

defineExpose({ dialogRef, contactsFormRef, onSuccess });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="4xl"
    overflow-y-auto
    sticky-footer
    @confirm="handleDialogConfirm"
  >
    <!-- Dialog header -->
    <div
      class="flex flex-col items-center pb-6 mb-2 text-center border-b border-n-weak"
    >
      <button
        type="button"
        :aria-label="t('DIALOG.BUTTONS.CANCEL')"
        class="absolute top-5 end-5 flex items-center justify-center size-10 rounded-lg text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
        @click="closeDialog"
      >
        <span class="i-lucide-x size-6" />
      </button>
      <div
        class="flex items-center justify-center rounded-full size-16 bg-n-brand/10 mb-4"
      >
        <span class="i-lucide-user-round size-8 text-n-brand" />
      </div>
      <h2 class="text-xl font-bold text-n-slate-12">
        {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SECTIONS.CUSTOMER') }}
      </h2>
      <p class="mt-1.5 text-base text-n-slate-10">
        {{
          t('CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.DIALOG_SUBTITLE')
        }}
      </p>
    </div>
    <ContactsForm
      ref="contactsFormRef"
      is-new-contact
      @update="createNewContact"
    />
    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <Button
          :label="t('DIALOG.BUTTONS.CANCEL')"
          variant="link"
          type="reset"
          class="h-11 text-base hover:!no-underline hover:text-n-brand"
          @click="closeDialog"
        />
        <Button
          type="submit"
          :label="
            t('CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.SAVE_CONTACT')
          "
          color="blue"
          class="!h-11 !text-base !px-5"
          :disabled="contactsFormRef?.isFormInvalid"
          :is-loading="isCreatingContact"
        />
      </div>
    </template>
  </Dialog>
</template>
