<script setup>
import { computed, onMounted, onBeforeUnmount, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import BackupsAPI from 'dashboard/api/backups';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const backups = ref([]);
const diskStats = ref({ total: 'N/A', used: 'N/A', free: 'N/A', percent: 0 });
const isFetching = ref(false);
const isCreating = ref(false);
const isPolling = ref(false);
let pollInterval = null;

const diskSpaceColor = computed(() => {
  const pct = diskStats.value.percent;
  if (pct > 85) return 'bg-n-ruby-9';
  if (pct > 65) return 'bg-n-amber-9';
  return 'bg-n-teal-9';
});

const localInterval = ref('4');
const isUpdatingInterval = ref(false);

const intervalOptions = [
  { value: '1', title: 'كل ساعة', desc: 'كل 60 دقيقة.' },
  { value: '4', title: 'كل 4 ساعات', desc: 'تكرار متوازن (افتراضي).' },
  { value: '8', title: 'كل 8 ساعات', desc: 'ثلاث مرات يومياً.' },
  { value: '12', title: 'كل 12 ساعة', desc: 'مرتين يومياً.' },
  { value: '24', title: 'يومياً', desc: 'مرة واحدة كل 24 ساعة.' }
];

const fetchBackups = async (silent = false) => {
  if (!silent) isFetching.value = true;
  try {
    const response = await BackupsAPI.get();
    backups.value = response.data.backups || [];
    if (response.data.disk_stats) {
      diskStats.value = response.data.disk_stats;
    }
    if (response.data.cron_interval) {
      localInterval.value = response.data.cron_interval;
    }
  } catch (error) {
    useAlert('فشل تحميل قائمة النسخ الاحتياطية.');
  } finally {
    if (!silent) isFetching.value = false;
  }
};

const updateInterval = async (val) => {
  isUpdatingInterval.value = true;
  try {
    const response = await BackupsAPI.update(val);
    localInterval.value = response.data.cron_interval;
    useAlert('تم تحديث جدولة النسخ الاحتياطي التلقائي بنجاح!');
  } catch (error) {
    useAlert('فشل تحديث جدولة النسخ الاحتياطي.');
    fetchBackups(true);
  } finally {
    isUpdatingInterval.value = false;
  }
};

const downloadBackup = async (filename) => {
  try {
    const response = await BackupsAPI.download(filename);
    const blobUrl = window.URL.createObjectURL(response.data);
    const link = document.createElement('a');
    link.href = blobUrl;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.URL.revokeObjectURL(blobUrl);
  } catch (error) {
    useAlert('فشل تنزيل النسخة الاحتياطية.');
  }
};

const triggerBackup = async () => {
  if (isCreating.value || isPolling.value) return;
  isCreating.value = true;
  try {
    await BackupsAPI.create();
    useAlert('بدأت عملية أخذ نسخة احتياطية في الخلفية. جاري المتابعة...');
    startPolling();
  } catch (error) {
    useAlert('فشل بدء عملية النسخ الاحتياطي.');
    isCreating.value = false;
  }
};

const startPolling = () => {
  isPolling.value = true;
  const initialFiles = new Set(backups.value.map(b => b.filename));
  let attempts = 0;

  pollInterval = setInterval(async () => {
    attempts += 1;
    // Stop polling after 15 attempts (45 seconds) to avoid infinite loops
    if (attempts > 15) {
      stopPolling();
      isCreating.value = false;
      useAlert('استغرقت العملية وقتاً أطول من المتوقع. يرجى تحديث الصفحة يدوياً لاحقاً.');
      return;
    }

    try {
      const response = await BackupsAPI.get();
      const currentFiles = response.data.backups || [];
      if (response.data.disk_stats) {
        diskStats.value = response.data.disk_stats;
      }
      
      // Look for any file not present in initial files
      const newFileFound = currentFiles.some(b => !initialFiles.has(b.filename));
      if (newFileFound) {
        backups.value = currentFiles;
        stopPolling();
        isCreating.value = false;
        useAlert('تم إنشاء النسخة الاحتياطية بنجاح وتحديث القائمة!');
      }
    } catch (e) {
      // Ignore poll errors, retry
    }
  }, 3000);
};

const stopPolling = () => {
  if (pollInterval) {
    clearInterval(pollInterval);
    pollInterval = null;
  }
  isPolling.value = false;
};

const deleteBackup = async (filename) => {
  const confirmed = window.confirm(`هل أنت متأكد من رغبتك في حذف النسخة الاحتياطية (${filename}) نهائياً من السيرفر؟`);
  if (!confirmed) return;

  try {
    await BackupsAPI.delete(filename);
    useAlert('تم حذف النسخة الاحتياطية بنجاح.');
    await fetchBackups();
  } catch (error) {
    useAlert('حدث خطأ أثناء محاولة حذف الملف.');
  }
};

const formatDate = (dateStr) => {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  return d.toLocaleString('ar-EG', {
    dateStyle: 'medium',
    timeStyle: 'short',
    hour12: true
  });
};

onMounted(() => {
  fetchBackups();
});

onBeforeUnmount(() => {
  stopPolling();
});
</script>

<template>
  <SettingsLayout
    :is-loading="isFetching"
    loading-message="جاري تحميل إعدادات النسخ الاحتياطي..."
  >
    <template #header>
      <BaseSettingsHeader
        title="النسخ الاحتياطي لقاعدة البيانات"
        description="إدارة وتحميل النسخ الاحتياطية لقاعدة بيانات النظام تلقائياً ويدوياً."
        icon-name="database"
        :show-back="false"
      />
    </template>

    <template #body>
      <div class="flex flex-col gap-6 font-inter rtl:font-sans">
        
        <!-- Disk Storage Visualizer -->
        <SectionLayout
          title="مساحة تخزين السيرفر"
          description="حالة القرص الصلب والمساحة المتوفرة للنسخ الاحتياطية."
        >
          <div class="rounded-xl border border-n-weak bg-n-solid-1 p-5">
            <div class="flex flex-row justify-between items-center mb-3">
              <div class="flex flex-col">
                <span class="text-[13px] text-n-slate-11">المساحة المتوفرة</span>
                <span class="text-[20px] font-bold text-n-slate-12">
                  {{ diskStats.free }} فارغ من أصل {{ diskStats.total }}
                </span>
              </div>
              <div class="text-[14px] font-semibold text-n-slate-12">
                تم استخدام {{ diskStats.percent }}%
              </div>
            </div>
            
            <!-- Progress Bar -->
            <div class="w-full h-3 rounded-full bg-n-alpha-2 overflow-hidden">
              <div
                class="h-full transition-all duration-500"
                :class="diskSpaceColor"
                :style="{ width: `${diskStats.percent}%` }"
              />
            </div>
            
            <!-- Storage Info Footnote -->
            <p class="mt-3 text-[12.5px] leading-relaxed text-n-slate-11">
              * يتم حفظ النسخ الاحتياطية محلياً على القرص الصلب للسيرفر. يرجى مراقبة المساحة بانتظام لضمان استمرار عملية النسخ الاحتياطي.
            </p>
          </div>
        </SectionLayout>

        <!-- Backup Interval Options -->
        <SectionLayout
          title="تكرار النسخ الاحتياطي التلقائي"
          description="اختر الفترة الزمنية لتشغيل عملية النسخ الاحتياطي التلقائي لقاعدة البيانات (سيتم الاحتفاظ فقط بنسخ آخر 7 أيام تلقائياً)."
        >
          <div class="grid gap-3 sm:grid-cols-5 text-right font-inter rtl:font-sans">
            <label
              v-for="opt in intervalOptions"
              :key="opt.value"
              class="group flex cursor-pointer items-start gap-3 rounded-xl border bg-n-solid-1 p-4 transition-all"
              :class="
                localInterval === opt.value
                  ? 'border-n-brand ring-2 ring-n-brand/30 shadow-sm'
                  : 'border-n-weak hover:border-n-slate-6'
              "
            >
              <input
                v-model="localInterval"
                type="radio"
                :value="opt.value"
                class="sr-only"
                :disabled="isUpdatingInterval"
                @change="updateInterval(opt.value)"
              />
              <div class="min-w-0 flex-1">
                <p class="text-[14px] font-semibold text-n-slate-12">
                  {{ opt.title }}
                </p>
                <p class="mt-1 text-[12px] leading-relaxed text-n-slate-11">
                  {{ opt.desc }}
                </p>
              </div>
              <span
                class="mt-1 grid size-5 shrink-0 place-items-center rounded-full ring-2"
                :class="
                  localInterval === opt.value
                    ? 'bg-n-brand ring-n-brand'
                    : 'bg-transparent ring-n-slate-6'
                "
                aria-hidden="true"
              >
                <span
                  v-if="localInterval === opt.value"
                  class="size-2 rounded-full bg-white"
                />
              </span>
            </label>
          </div>
        </SectionLayout>

        <!-- Backup List Table -->
        <SectionLayout
          title="النسخ الاحتياطية المتوفرة"
          description="جدول يعرض ملفات النسخ المتوفرة حالياً على السيرفر ومواعيد حذفها التلقائي."
        >
          <template #headerActions>
            <NextButton
              :disabled="isCreating || isPolling"
              class="rounded-xl px-4 py-2 font-semibold"
              :class="isCreating || isPolling ? 'opacity-60' : ''"
              label="أخذ نسخة احتياطية الآن"
              icon="i-lucide-plus"
              @click="triggerBackup"
            />
          </template>

          <div class="overflow-x-auto rounded-xl border border-n-weak bg-n-solid-1">
            <table class="w-full border-collapse text-right text-[13.5px]">
              <thead>
                <tr class="border-b border-n-weak bg-n-solid-2 text-n-slate-11 font-semibold">
                  <th class="p-4">اسم الملف</th>
                  <th class="p-4">تاريخ الإنشاء</th>
                  <th class="p-4">تاريخ الحذف المتوقع</th>
                  <th class="p-4">الحجم</th>
                  <th class="p-4 text-center">العمليات</th>
                </tr>
              </thead>
              <tbody>
                <!-- Polling Row Placeholder -->
                <tr v-if="isCreating || isPolling" class="border-b border-n-weak bg-n-amber-1 animate-pulse">
                  <td class="p-4 font-medium text-n-amber-11 flex items-center gap-2">
                    <span class="i-lucide-loader-circle size-4 animate-spin shrink-0" />
                    جاري معالجة وإنشاء نسخة احتياطية جديدة...
                  </td>
                  <td class="p-4 text-n-slate-10">-</td>
                  <td class="p-4 text-n-slate-10">-</td>
                  <td class="p-4 text-n-slate-10">-</td>
                  <td class="p-4 text-center text-n-slate-10">-</td>
                </tr>

                <!-- Backups Files Rows -->
                <tr
                  v-for="backup in backups"
                  :key="backup.filename"
                  class="border-b border-n-weak hover:bg-n-alpha-1 transition-colors"
                >
                  <td class="p-4 font-mono font-medium text-n-slate-12 max-w-[280px] truncate" :title="backup.filename">
                    {{ backup.filename }}
                  </td>
                  <td class="p-4 text-n-slate-11">
                    {{ formatDate(backup.created_at) }}
                  </td>
                  <td class="p-4 text-n-amber-11 font-medium">
                    {{ formatDate(backup.delete_at) }}
                  </td>
                  <td class="p-4 text-n-slate-11 font-semibold">
                    {{ backup.size }}
                  </td>
                  <td class="p-4">
                    <div class="flex items-center justify-center gap-2">
                      <button
                        type="button"
                        class="inline-flex items-center justify-center gap-1.5 rounded-lg border border-n-weak bg-white px-3 py-1.5 text-[12.5px] font-semibold text-n-slate-12 transition-all hover:bg-n-alpha-1 active:scale-[0.97]"
                        @click="downloadBackup(backup.filename)"
                      >
                        <span class="i-lucide-download size-3.5" />
                        تنزيل
                      </button>
                      <button
                        type="button"
                        class="inline-flex items-center justify-center gap-1.5 rounded-lg border border-n-ruby-4 bg-white px-3 py-1.5 text-[12.5px] font-semibold text-n-ruby-11 transition-all hover:bg-n-ruby-2 active:scale-[0.97]"
                        @click="deleteBackup(backup.filename)"
                      >
                        <span class="i-lucide-trash size-3.5" />
                        حذف
                      </button>
                    </div>
                  </td>
                </tr>

                <!-- Empty State -->
                <tr v-if="backups.length === 0 && !isCreating && !isPolling">
                  <td colspan="5" class="p-12 text-center text-n-slate-10">
                    <div class="flex flex-col items-center justify-center gap-2">
                      <span class="i-lucide-database-backup size-8 text-n-slate-8" />
                      <span>لا توجد أي نسخ احتياطية متوفرة حالياً.</span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </SectionLayout>

      </div>
    </template>
  </SettingsLayout>
</template>

<style scoped>
/* Scoped RTL styling if needed */
</style>
