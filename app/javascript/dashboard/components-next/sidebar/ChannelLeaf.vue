<script setup>
import { computed } from 'vue';
import Icon from 'next/icon/Icon.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import { useMapGetter } from 'dashboard/composables/store';

const props = defineProps({
  label: {
    type: String,
    required: true,
  },
  // eslint-disable-next-line vue/no-unused-properties
  active: {
    type: Boolean,
    default: false,
  },
  inbox: {
    type: Object,
    required: true,
  },
});

const reauthorizationRequired = computed(() => {
  return props.inbox.reauthorization_required;
});

const getUnattendedCount = useMapGetter('inboxes/getUnattendedCount');

const unattendedCount = computed(() =>
  getUnattendedCount.value(props.inbox.id)
);

const countLabel = computed(() =>
  unattendedCount.value > 99 ? '99+' : unattendedCount.value
);

// Eltafouk: per-page comment inboxes (Channel::Api) get platform tints
// instead of the generic API orange. Keep IDs in sync with the override
// in ../icon/provider.js.
const ELTAFOUK_COMMENT_TINTS = {
  24: '#1877F2', // FB · التفوق للثانوية العامة
  25: '#1877F2', // FB · كتاب التفوق
  26: '#1877F2', // FB · التفوق للنشر والتوزيع
  27: '#E1306C', // IG · eltafouk_book
};

const commentTint = computed(() => ELTAFOUK_COMMENT_TINTS[props.inbox.id]);
const isCommentInbox = computed(() => Boolean(commentTint.value));

// Tinted rounded-square container for comment inboxes — gives each page a
// branded "avatar" feel instead of the generic gray circle that DM channels
// keep.
const commentIconContainerStyle = computed(() => {
  if (!commentTint.value) return null;
  return {
    backgroundColor: `${commentTint.value}1F`, // ~12% alpha
    boxShadow: `inset 0 0 0 1px ${commentTint.value}33`,
  };
});

const channelColor = computed(() => {
  const type = props.inbox.channel_type;
  const medium = props.inbox.medium;

  if (commentTint.value) {
    return `color: ${commentTint.value};`;
  }

  if (
    type === 'Channel::Whatsapp' ||
    (type === 'Channel::TwilioSms' && medium === 'whatsapp')
  ) {
    return 'color: #16a34a;'; // Green
  }
  if (type === 'Channel::FacebookPage') {
    return 'color: #2563eb;'; // Blue
  }
  if (type === 'Channel::Instagram') {
    return 'color: #9333ea;'; // Purple
  }
  if (type === 'Channel::Telegram') {
    return 'color: #0ea5e9;'; // Light Blue
  }
  if (type === 'Channel::Api') {
    return 'color: #ea580c;'; // Orange
  }
  if (type === 'Channel::Email') {
    return 'color: #db2777;'; // Pink
  }
  return '';
});
</script>

<template>
  <span
    class="grid place-content-center transition-colors"
    :class="[
      isCommentInbox
        ? 'size-6 rounded-[6px]'
        : 'size-5 rounded-full bg-n-alpha-2',
    ]"
    :style="commentIconContainerStyle"
  >
    <ChannelIcon
      :inbox="inbox"
      :class="isCommentInbox ? 'size-3.5' : 'size-3'"
      :style="channelColor"
    />
  </span>
  <div
    class="flex-1 truncate min-w-0 transition-colors duration-300"
    :class="[
      unattendedCount ? 'font-medium text-n-slate-12' : 'text-n-slate-11',
    ]"
  >
    {{ label }}
  </div>
  <span
    v-if="unattendedCount"
    dir="ltr"
    class="inline-flex h-[18px] min-w-[18px] flex-shrink-0 items-center justify-center rounded-full bg-[#b91c1c] px-1 text-[10px] font-semibold leading-none text-white tabular-nums animate-calm-breath"
  >
    {{ countLabel }}
  </span>
  <div
    v-if="reauthorizationRequired"
    v-tooltip.top-end="$t('SIDEBAR.REAUTHORIZE')"
    class="grid place-content-center size-5 bg-n-ruby-5/60 rounded-full"
  >
    <Icon icon="i-woot-alert" class="size-3 text-n-ruby-9" />
  </div>
</template>

<style scoped>
@keyframes calm-breath {
  0%,
  100% {
    transform: scale(1);
    box-shadow: 0 0 0 0 rgba(185, 28, 28, 0.4);
  }
  50% {
    transform: scale(1.05);
    box-shadow: 0 0 0 4px rgba(185, 28, 28, 0);
  }
}

.animate-calm-breath {
  animation: calm-breath 2.5s ease-in-out infinite;
}
</style>
