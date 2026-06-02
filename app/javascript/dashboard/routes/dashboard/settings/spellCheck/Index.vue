<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { storeToRefs } from 'pinia';
import { useAlert } from 'dashboard/composables';
import { useSpellCheckSettingsStore } from 'dashboard/store/spellCheckSettings';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SectionLayout from '../account/components/SectionLayout.vue';

const { t } = useI18n();
const store = useSpellCheckSettingsStore();
const { settings, longMessageThreshold, uiFlags } = storeToRefs(store);

const localDmEnabled = ref(true);
const localCommentsEnabled = ref(false);
const localLongStrategy = ref('skip');

const longStrategyOptions = computed(() => [
  {
    value: 'skip',
    title: t('SPELL_CHECK_SETTINGS.LONG_STRATEGY.SKIP_TITLE'),
    desc: t('SPELL_CHECK_SETTINGS.LONG_STRATEGY.SKIP_DESC', {
      threshold: longMessageThreshold.value,
    }),
    badge: t('SPELL_CHECK_SETTINGS.LONG_STRATEGY.BADGE_FREE'),
    icon: 'i-lucide-fast-forward',
    iconBg: 'bg-n-slate-3',
    iconRing: 'ring-n-slate-7',
    iconColor: 'text-n-slate-11',
  },
  {
    value: 'nano',
    title: t('SPELL_CHECK_SETTINGS.LONG_STRATEGY.NANO_TITLE'),
    desc: t('SPELL_CHECK_SETTINGS.LONG_STRATEGY.NANO_DESC'),
    badge: t('SPELL_CHECK_SETTINGS.LONG_STRATEGY.BADGE_CHEAP'),
    icon: 'i-lucide-zap',
    iconBg: 'bg-n-teal-3',
    iconRing: 'ring-n-teal-7',
    iconColor: 'text-n-teal-11',
  },
  {
    value: 'mini',
    title: t('SPELL_CHECK_SETTINGS.LONG_STRATEGY.MINI_TITLE'),
    desc: t('SPELL_CHECK_SETTINGS.LONG_STRATEGY.MINI_DESC'),
    badge: t('SPELL_CHECK_SETTINGS.LONG_STRATEGY.BADGE_QUALITY'),
    icon: 'i-lucide-sparkles',
    iconBg: 'bg-n-amber-3',
    iconRing: 'ring-n-amber-7',
    iconColor: 'text-n-amber-11',
  },
  {
    value: 'hybrid',
    title: t('SPELL_CHECK_SETTINGS.LONG_STRATEGY.HYBRID_TITLE'),
    desc: t('SPELL_CHECK_SETTINGS.LONG_STRATEGY.HYBRID_DESC', {
      threshold: longMessageThreshold.value,
    }),
    badge: t('SPELL_CHECK_SETTINGS.LONG_STRATEGY.BADGE_BALANCED'),
    icon: 'i-lucide-shuffle',
    iconBg: 'bg-n-iris-3',
    iconRing: 'ring-n-iris-7',
    iconColor: 'text-n-iris-11',
  },
]);

const isLoading = computed(() => uiFlags.value.isFetching);
const isSaving = computed(() => uiFlags.value.isUpdating);

const refreshFromStore = () => {
  localDmEnabled.value = settings.value.dm_enabled !== false;
  localCommentsEnabled.value = settings.value.comments_enabled === true;
  localLongStrategy.value = settings.value.long_message_strategy || 'skip';
};

watch(settings, refreshFromStore, { deep: true });

onMounted(async () => {
  await store.fetch();
  refreshFromStore();
});

const save = async () => {
  try {
    await store.update({
      dm_enabled: localDmEnabled.value,
      comments_enabled: localCommentsEnabled.value,
      long_message_strategy: localLongStrategy.value,
    });
    useAlert(t('SPELL_CHECK_SETTINGS.SAVE_SUCCESS'));
  } catch (e) {
    useAlert(t('SPELL_CHECK_SETTINGS.SAVE_FAILED'));
  }
};
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="t('SPELL_CHECK_SETTINGS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('SPELL_CHECK_SETTINGS.TITLE')"
        :description="t('SPELL_CHECK_SETTINGS.DESCRIPTION')"
        icon-name="spell-check"
        :show-back="false"
      />
    </template>

    <template #body>
      <div class="flex flex-col gap-1">
        <!-- Where it runs -->
        <SectionLayout
          :title="t('SPELL_CHECK_SETTINGS.SCOPE.TITLE')"
          :description="t('SPELL_CHECK_SETTINGS.SCOPE.DESCRIPTION')"
        >
          <div class="flex flex-col gap-4">
            <!-- DM toggle -->
            <label
              class="group flex cursor-pointer items-start justify-between gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4 transition-colors hover:border-n-slate-6"
            >
              <div class="flex items-start gap-3">
                <span
                  class="grid size-9 shrink-0 place-items-center rounded-lg bg-n-teal-3 ring-1 ring-n-teal-6"
                  aria-hidden="true"
                >
                  <span
                    class="i-lucide-message-square size-[18px] text-n-teal-11"
                  />
                </span>
                <div>
                  <p class="text-[14.5px] font-medium text-n-slate-12">
                    {{ t('SPELL_CHECK_SETTINGS.SCOPE.DM_LABEL') }}
                  </p>
                  <p class="mt-1 text-[12.5px] text-n-slate-11">
                    {{ t('SPELL_CHECK_SETTINGS.SCOPE.DM_DESCRIPTION') }}
                  </p>
                </div>
              </div>
              <input
                v-model="localDmEnabled"
                type="checkbox"
                class="peer sr-only"
              />
              <span
                class="relative mt-1 inline-block h-6 w-11 shrink-0 rounded-full bg-n-alpha-3 transition-colors peer-checked:bg-n-brand"
              >
                <span
                  class="absolute start-0.5 top-0.5 size-5 rounded-full bg-white shadow-sm transition-transform peer-checked:translate-x-[1.25rem] rtl:peer-checked:-translate-x-[1.25rem]"
                  :class="
                    localDmEnabled
                      ? 'translate-x-[1.25rem] rtl:-translate-x-[1.25rem]'
                      : ''
                  "
                />
              </span>
            </label>

            <!-- Comments toggle -->
            <label
              class="group flex cursor-pointer items-start justify-between gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4 transition-colors hover:border-n-slate-6"
            >
              <div class="flex items-start gap-3">
                <span
                  class="grid size-9 shrink-0 place-items-center rounded-lg bg-n-iris-3 ring-1 ring-n-iris-6"
                  aria-hidden="true"
                >
                  <span
                    class="i-lucide-messages-square size-[18px] text-n-iris-11"
                  />
                </span>
                <div>
                  <p class="text-[14.5px] font-medium text-n-slate-12">
                    {{ t('SPELL_CHECK_SETTINGS.SCOPE.COMMENTS_LABEL') }}
                  </p>
                  <p class="mt-1 text-[12.5px] text-n-slate-11">
                    {{ t('SPELL_CHECK_SETTINGS.SCOPE.COMMENTS_DESCRIPTION') }}
                  </p>
                </div>
              </div>
              <input
                v-model="localCommentsEnabled"
                type="checkbox"
                class="peer sr-only"
              />
              <span
                class="relative mt-1 inline-block h-6 w-11 shrink-0 rounded-full bg-n-alpha-3 transition-colors peer-checked:bg-n-brand"
              >
                <span
                  class="absolute start-0.5 top-0.5 size-5 rounded-full bg-white shadow-sm transition-transform"
                  :class="
                    localCommentsEnabled
                      ? 'translate-x-[1.25rem] rtl:-translate-x-[1.25rem]'
                      : ''
                  "
                />
              </span>
            </label>
          </div>
        </SectionLayout>

        <!-- Long message strategy -->
        <SectionLayout
          :title="t('SPELL_CHECK_SETTINGS.LONG_STRATEGY.TITLE')"
          :description="
            t('SPELL_CHECK_SETTINGS.LONG_STRATEGY.DESCRIPTION', {
              threshold: longMessageThreshold,
            })
          "
          with-border
        >
          <div class="grid gap-3 sm:grid-cols-2">
            <label
              v-for="opt in longStrategyOptions"
              :key="opt.value"
              class="group flex cursor-pointer items-start gap-3 rounded-xl border bg-n-solid-1 p-4 transition-all"
              :class="
                localLongStrategy === opt.value
                  ? 'border-n-brand ring-2 ring-n-brand/30 shadow-sm'
                  : 'border-n-weak hover:border-n-slate-6'
              "
            >
              <input
                v-model="localLongStrategy"
                type="radio"
                :value="opt.value"
                class="sr-only"
              />
              <span
                class="mt-px grid size-9 shrink-0 place-items-center rounded-lg ring-1"
                :class="[opt.iconBg, opt.iconRing]"
                aria-hidden="true"
              >
                <span class="size-[18px]" :class="[opt.icon, opt.iconColor]" />
              </span>
              <div class="min-w-0 flex-1">
                <div class="flex items-center gap-2">
                  <p class="text-[14px] font-semibold text-n-slate-12">
                    {{ opt.title }}
                  </p>
                  <span
                    class="rounded-full bg-n-alpha-2 px-2 py-0.5 text-[10px] font-bold text-n-slate-11"
                  >
                    {{ opt.badge }}
                  </span>
                </div>
                <p class="mt-1 text-[12.5px] leading-relaxed text-n-slate-11">
                  {{ opt.desc }}
                </p>
              </div>
              <span
                class="mt-1 grid size-5 shrink-0 place-items-center rounded-full ring-2"
                :class="
                  localLongStrategy === opt.value
                    ? 'bg-n-brand ring-n-brand'
                    : 'bg-transparent ring-n-slate-6'
                "
                aria-hidden="true"
              >
                <span
                  v-if="localLongStrategy === opt.value"
                  class="size-2 rounded-full bg-white"
                />
              </span>
            </label>
          </div>

          <!-- Save action — covers all sections -->
          <div class="mt-6 flex justify-end">
            <button
              type="button"
              :disabled="isSaving"
              class="inline-flex h-10 items-center gap-2 rounded-lg bg-n-brand px-5 text-[13px] font-semibold text-white shadow-md shadow-n-brand/25 transition-all hover:brightness-110 hover:shadow-lg hover:shadow-n-brand/35 active:scale-[0.98] disabled:opacity-60"
              @click="save"
            >
              <span
                v-if="isSaving"
                class="i-lucide-loader-circle size-4 animate-spin"
              />
              <span v-else class="i-lucide-check size-4" />
              {{
                isSaving
                  ? t('SPELL_CHECK_SETTINGS.SAVING')
                  : t('SPELL_CHECK_SETTINGS.SAVE')
              }}
            </button>
          </div>
        </SectionLayout>
      </div>
    </template>
  </SettingsLayout>
</template>
