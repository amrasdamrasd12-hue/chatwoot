<script setup>
import { computed, ref } from 'vue';
import { getInboxIconByType } from 'dashboard/helper/inbox';
import { useRouter, useRoute } from 'vue-router';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper.js';
import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import CardMessagePreview from './CardMessagePreview.vue';
import CardMessagePreviewWithMeta from './CardMessagePreviewWithMeta.vue';
import CardPriorityIcon from './CardPriorityIcon.vue';

const props = defineProps({
  conversation: {
    type: Object,
    required: true,
  },
  contact: {
    type: Object,
    required: true,
  },
  stateInbox: {
    type: Object,
    required: true,
  },
  accountLabels: {
    type: Array,
    required: true,
  },
});

const router = useRouter();
const route = useRoute();

const cardMessagePreviewWithMetaRef = ref(null);

const currentContact = computed(() => props.contact);

const currentContactName = computed(() => currentContact.value?.name);
const currentContactThumbnail = computed(() => currentContact.value?.thumbnail);
const currentContactStatus = computed(
  () => currentContact.value?.availabilityStatus
);

const inbox = computed(() => props.stateInbox);

const inboxName = computed(() => inbox.value?.name);

const inboxIcon = computed(() => {
  const { channelType, medium } = inbox.value;
  return getInboxIconByType(channelType, medium);
});

const lastActivityAt = computed(() => {
  const timestamp = props.conversation?.timestamp;
  return timestamp ? shortTimestamp(dynamicTime(timestamp)) : '';
});

const usedPhoneLabel = computed(() => {
  const sourceId = props.conversation?.meta?.source_id;
  if (!sourceId) return null;

  const primaryLast10 = (currentContact.value?.phoneNumber || '')
    .replace(/\D/g, '')
    .slice(-10);
  const sourceLast10 = String(sourceId).replace(/\D/g, '').slice(-10);

  if (primaryLast10 && primaryLast10 === sourceLast10) return null;

  const attrs = currentContact.value?.additionalAttributes || {};

  const mobileNumbers = Array.isArray(attrs.customCustomerMobileNumbers)
    ? attrs.customCustomerMobileNumbers
    : [];
  const matchedRow = mobileNumbers.find(
    row =>
      String(row.phone || '')
        .replace(/\D/g, '')
        .slice(-10) === sourceLast10
  );
  if (matchedRow) return matchedRow.mobileOwner || matchedRow.phone;

  if (
    String(attrs.phoneSecondary || '')
      .replace(/\D/g, '')
      .slice(-10) === sourceLast10
  )
    return attrs.phoneSecondary;

  if (
    String(attrs.phoneAlternative || '')
      .replace(/\D/g, '')
      .slice(-10) === sourceLast10
  )
    return attrs.phoneAlternative;

  return sourceId;
});

const showMessagePreviewWithoutMeta = computed(() => {
  const { labels = [] } = props.conversation;
  return (
    !cardMessagePreviewWithMetaRef.value?.hasSlaThreshold && labels.length === 0
  );
});

const onCardClick = e => {
  const path = frontendURL(
    conversationUrl({
      accountId: route.params.accountId,
      id: props.conversation.id,
    })
  );

  if (e.metaKey || e.ctrlKey) {
    window.open(
      window.chatwootConfig.hostURL + path,
      '_blank',
      'noopener noreferrer nofollow'
    );
    return;
  }
  router.push({ path });
};
</script>

<template>
  <div
    role="button"
    class="flex w-full gap-3 px-3 py-4 transition-all duration-300 ease-in-out cursor-pointer"
    @click="onCardClick"
  >
    <Avatar
      :name="currentContactName"
      :src="currentContactThumbnail"
      :size="24"
      :status="currentContactStatus"
      rounded-full
    />
    <div class="flex flex-col w-full gap-1 min-w-0">
      <div class="flex items-center justify-between h-6 gap-2">
        <div class="flex items-center gap-2 min-w-0">
          <h4 class="text-base font-medium truncate text-n-slate-12">
            {{ currentContactName }}
          </h4>
          <span
            v-if="usedPhoneLabel"
            class="flex-shrink-0 inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md text-xs bg-n-alpha-2 text-n-slate-11 border border-n-weak"
          >
            <span class="i-lucide-phone size-2.5" />
            {{ usedPhoneLabel }}
          </span>
        </div>
        <div class="flex items-center gap-2">
          <CardPriorityIcon :priority="conversation.priority || null" />
          <div
            v-tooltip.left="inboxName"
            class="flex items-center justify-center flex-shrink-0 rounded-full bg-n-alpha-2 size-5"
          >
            <Icon
              :icon="inboxIcon"
              class="flex-shrink-0 text-n-slate-11 size-3"
            />
          </div>
          <span class="text-sm text-n-slate-10">
            {{ lastActivityAt }}
          </span>
        </div>
      </div>
      <CardMessagePreview
        v-show="showMessagePreviewWithoutMeta"
        :conversation="conversation"
      />
      <CardMessagePreviewWithMeta
        v-show="!showMessagePreviewWithoutMeta"
        ref="cardMessagePreviewWithMetaRef"
        :conversation="conversation"
        :account-labels="accountLabels"
      />
    </div>
  </div>
</template>
