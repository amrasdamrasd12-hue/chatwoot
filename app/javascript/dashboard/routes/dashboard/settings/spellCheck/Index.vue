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
const { settings, strictnessLabels, uiFlags } = storeToRefs(store);

const localDmEnabled = ref(true);
const localCommentsEnabled = ref(false);
const localStrictness = ref(3);

const isLoading = computed(() => uiFlags.value.isFetching);
const isSaving = computed(() => uiFlags.value.isUpdating);

// Cosmetic guidance shown beneath the strictness slider. The model
// receives the same intent via the Liquid template; this is just the
// human-readable companion.
const strictnessHelp = computed(() => {
  const map = {
    1: 'يصحّح فقط أوضح الأخطاء الإملائية. مناسب للبداية.',
    2: 'يصحّح الأخطاء الإملائية الشائعة فقط.',
    3: 'إملاء + قواعد بسيطة. مستوى متوازن.',
    4: 'إملاء + قواعد + تنوين وهمزات.',
    5: 'كل القواعد النحوية. للموظفين المتمرّسين.',
    6: 'أعلى مستوى. يصحّح كل خطأ مهما كان طفيفاً.',
  };
  return map[localStrictness.value] || '';
});

const refreshFromStore = () => {
  localDmEnabled.value = settings.value.dm_enabled !== false;
  localCommentsEnabled.value = settings.value.comments_enabled === true;
  localStrictness.value = Number(settings.value.strictness) || 3;
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
      strictness: localStrictness.value,
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

        <!-- Strictness -->
        <SectionLayout
          :title="t('SPELL_CHECK_SETTINGS.STRICTNESS.TITLE')"
          :description="t('SPELL_CHECK_SETTINGS.STRICTNESS.DESCRIPTION')"
          with-border
        >
          <div class="flex flex-col gap-4">
            <!-- Current level chip -->
            <div class="flex items-center gap-3">
              <span
                class="rounded-full bg-n-amber-3 px-3 py-1 text-[12px] font-bold text-n-amber-12 ring-1 ring-n-amber-7"
              >
                {{
                  t('SPELL_CHECK_SETTINGS.STRICTNESS.LEVEL_BADGE', {
                    level: localStrictness,
                  })
                }}
              </span>
              <span class="text-[15px] font-semibold text-n-slate-12">
                {{ strictnessLabels[localStrictness] }}
              </span>
            </div>

            <!-- Slider -->
            <div class="rounded-xl border border-n-weak bg-n-solid-1 p-5">
              <input
                v-model.number="localStrictness"
                type="range"
                min="1"
                max="6"
                step="1"
                class="h-2 w-full cursor-pointer appearance-none rounded-full bg-n-alpha-2 accent-n-brand outline-none"
              />
              <div
                class="mt-3 grid grid-cols-6 gap-1 text-center text-[11px] font-medium text-n-slate-11"
              >
                <button
                  v-for="lvl in 6"
                  :key="lvl"
                  type="button"
                  class="rounded-md py-1 transition-colors"
                  :class="
                    localStrictness === lvl
                      ? 'bg-n-brand text-white'
                      : 'hover:bg-n-alpha-2'
                  "
                  @click="localStrictness = lvl"
                >
                  {{ strictnessLabels[lvl] }}
                </button>
              </div>
              <p
                class="mt-3 rounded-md bg-n-alpha-1 px-3 py-2 text-[12.5px] italic text-n-slate-11"
              >
                {{ strictnessHelp }}
              </p>
            </div>

            <!-- Save action -->
            <div class="flex justify-end pt-2">
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
          </div>
        </SectionLayout>
      </div>
    </template>
  </SettingsLayout>
</template>
