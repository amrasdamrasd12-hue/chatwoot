<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import ContactAPI from 'dashboard/api/contacts';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { EGYPT_DISTRICTS } from 'dashboard/constants/egyptDistricts';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { getClassificationBadgeClass } from 'dashboard/helper/contactsClassificationColors';

const props = defineProps({
  contact: { type: Object, required: true },
  isSelected: { type: Boolean, default: false },
});

const emit = defineEmits(['select', 'showContact']);

const { t, locale } = useI18n();
const route = useRoute();
const router = useRouter();
const isOpeningConversation = ref(false);

const districtsMap = EGYPT_DISTRICTS.reduce((acc, d) => {
  acc[d.value] = d.label;
  return acc;
}, {});

const lastActivity = computed(() => {
  return props.contact.createdAt
    ? dynamicTime(props.contact.createdAt, locale.value)
    : t('CONTACTS_LAYOUT.TABLE.EMPTY_VALUE');
});

const selectedModel = computed({
  get: () => props.isSelected,
  set: value => emit('select', value),
});

const emptyValue = computed(() => t('CONTACTS_LAYOUT.TABLE.EMPTY_VALUE'));

const normalizePhone = phone => {
  if (!phone || phone.startsWith('+')) return phone;
  if (/^0\d+$/.test(phone)) return `+20${phone.slice(1)}`;
  return phone;
};

const defaultPhone = computed(() => {
  const numbers =
    props.contact.additionalAttributes?.customCustomerMobileNumbers || [];
  const row =
    numbers.find(r => r.defaultPhone && r.phone) || numbers.find(r => r.phone);
  return normalizePhone(row?.phone || props.contact.phoneNumber || '');
});

const classification = computed(
  () => props.contact.additionalAttributes?.customCustomerClassification || ''
);

const classificationBadgeClass = getClassificationBadgeClass;

const primaryAddress = computed(() => {
  const addresses = props.contact.additionalAttributes?.customAddresses || [];
  return addresses[0] || null;
});

const governorate = computed(() => primaryAddress.value?.governorate || '');

const districtLabel = computed(() => {
  const val = primaryAddress.value?.district;
  if (!val) return '';
  return districtsMap[val] || val;
});

const openLatestConversation = async () => {
  if (isOpeningConversation.value) return;

  isOpeningConversation.value = true;
  try {
    const {
      data: { payload = [] },
    } = await ContactAPI.getConversations(props.contact.id);
    const latestConversation = payload[0];

    if (!latestConversation?.id) {
      useAlert(t('CONTACTS_LAYOUT.TABLE.NO_CONVERSATION'));
      return;
    }

    const path = frontendURL(
      conversationUrl({
        accountId: route.params.accountId,
        id: latestConversation.id,
      })
    );
    router.push({ path });
  } finally {
    isOpeningConversation.value = false;
  }
};
</script>

<template>
  <tr
    class="h-10 transition-colors border-b cursor-pointer group/row border-n-weak last:border-b-0 hover:bg-n-alpha-2"
    :class="isSelected ? 'bg-n-blue-3' : 'bg-n-solid-1'"
    @click="emit('showContact', contact.id)"
  >
    <td class="px-3 py-1 text-center" @click.stop>
      <div class="flex items-center justify-center">
        <Checkbox v-model="selectedModel" />
      </div>
    </td>
    <td class="px-3 py-1">
      <div class="flex items-center min-w-0 gap-2.5">
        <Avatar
          :name="contact.name"
          :src="contact.thumbnail"
          :size="28"
          :status="contact.availabilityStatus"
          hide-offline-status
          rounded-full
        />
        <div class="min-w-0">
          <div
            dir="auto"
            class="text-sm font-medium leading-5 truncate text-start text-n-slate-12"
          >
            {{ contact.name || emptyValue }}
          </div>
          <span
            v-if="contact.conversationsCount"
            class="inline-flex items-center gap-0.5 px-1 py-0.5 rounded text-xs bg-n-alpha-2 text-n-slate-10 leading-none"
          >
            {{
              t('CONTACTS_LAYOUT.TABLE.CONVERSATIONS_COUNT', {
                count: contact.conversationsCount,
              })
            }}
          </span>
        </div>
      </div>
    </td>
    <td class="px-3 py-1 text-center">
      <div
        v-if="defaultPhone"
        class="inline-flex items-center justify-center max-w-full gap-1.5"
      >
        <span
          dir="ltr"
          class="inline-block max-w-full font-mono text-sm font-medium leading-5 truncate text-center text-n-slate-12 tabular-nums"
        >
          {{ defaultPhone }}
        </span>
        <Button
          v-tooltip.bottom="t('CONTACTS_LAYOUT.TABLE.OPEN_CONVERSATION')"
          :aria-label="t('CONTACTS_LAYOUT.TABLE.OPEN_CONVERSATION')"
          icon="i-lucide-message-circle"
          size="xs"
          color="slate"
          variant="ghost"
          class="!size-6 shrink-0 opacity-0 group-hover/row:opacity-100 transition-opacity"
          :is-loading="isOpeningConversation"
          @click.stop="openLatestConversation"
        />
      </div>
      <span
        v-else
        class="block w-full text-xs leading-5 text-center text-n-slate-8 select-none"
      >
        {{ emptyValue }}
      </span>
    </td>
    <td class="px-3 py-1 text-center">
      <span
        v-if="classification"
        class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-semibold"
        :class="classificationBadgeClass(classification)"
      >
        {{ classification }}
      </span>
      <span
        v-else
        class="block w-full text-xs leading-5 text-center text-n-slate-8 select-none"
      >
        {{ emptyValue }}
      </span>
    </td>
    <td class="px-3 py-1 text-center">
      <span
        v-if="governorate"
        dir="auto"
        class="block text-sm font-medium leading-5 truncate text-center text-n-slate-12"
      >
        {{ governorate }}
      </span>
      <span
        v-else
        class="block w-full text-xs leading-5 text-center text-n-slate-8 select-none"
      >
        {{ emptyValue }}
      </span>
    </td>
    <td class="px-3 py-1 text-center">
      <span
        v-if="districtLabel"
        dir="auto"
        class="block text-sm font-medium leading-5 truncate text-center text-n-slate-12"
      >
        {{ districtLabel }}
      </span>
      <span
        v-else
        class="block w-full text-xs leading-5 text-center text-n-slate-8 select-none"
      >
        {{ emptyValue }}
      </span>
    </td>
    <td class="px-3 py-1">
      <span
        v-if="contact.createdAt"
        dir="auto"
        class="block text-sm font-medium leading-5 whitespace-nowrap text-start text-n-slate-12"
      >
        {{ lastActivity }}
      </span>
      <span
        v-else
        class="block w-full text-xs leading-5 text-center text-n-slate-8 select-none"
      >
        {{ emptyValue }}
      </span>
    </td>
  </tr>
</template>
