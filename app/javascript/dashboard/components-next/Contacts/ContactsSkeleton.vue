<script setup>
defineProps({
  viewMode: {
    type: String,
    default: 'table',
    validator: value => ['table', 'card'].includes(value),
  },
});

const rows = Array.from({ length: 8 }, (_, index) => index);
const cards = Array.from({ length: 6 }, (_, index) => index);
</script>

<template>
  <div class="flex flex-col gap-4 px-4 pt-4 pb-6 sm:px-6 lg:px-8">
    <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
      <div
        v-for="item in 4"
        :key="item"
        class="flex items-center gap-3 px-4 py-3 rounded-lg bg-n-solid-2 outline outline-1 outline-n-container -outline-offset-1"
      >
        <div class="rounded-lg size-9 bg-n-alpha-2 animate-pulse" />
        <div class="flex flex-col flex-1 gap-2">
          <div class="w-12 h-4 rounded bg-n-alpha-2 animate-pulse" />
          <div class="w-24 h-3 rounded bg-n-alpha-2 animate-pulse" />
        </div>
      </div>
    </div>

    <div class="flex flex-wrap gap-2">
      <div
        v-for="item in 4"
        :key="item"
        class="w-24 h-8 rounded-lg bg-n-alpha-2 animate-pulse"
      />
    </div>

    <div
      v-if="viewMode === 'table'"
      class="overflow-hidden rounded-lg bg-n-solid-2 outline outline-1 outline-n-container -outline-offset-1"
    >
      <div class="w-full overflow-x-auto">
        <table class="w-full text-sm border-collapse table-fixed min-w-[72rem]">
          <thead class="bg-n-solid-2">
            <tr>
              <th v-for="item in 8" :key="item" class="px-4 py-3">
                <div class="w-20 h-3 rounded bg-n-alpha-2 animate-pulse" />
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in rows" :key="row" class="border-t border-n-weak">
              <td class="px-4 py-4">
                <div class="w-4 h-4 rounded bg-n-alpha-2 animate-pulse" />
              </td>
              <td class="px-4 py-4">
                <div class="flex items-center gap-3">
                  <div class="rounded-full size-9 bg-n-alpha-2 animate-pulse" />
                  <div class="flex flex-col gap-2">
                    <div class="w-32 h-4 rounded bg-n-alpha-2 animate-pulse" />
                    <div class="w-20 h-3 rounded bg-n-alpha-2 animate-pulse" />
                  </div>
                </div>
              </td>
              <td v-for="cell in 6" :key="cell" class="px-4 py-4">
                <div class="h-4 rounded bg-n-alpha-2 animate-pulse w-28" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div v-else class="flex flex-col gap-4">
      <div
        v-for="card in cards"
        :key="card"
        class="flex items-center gap-4 px-6 py-5 rounded-xl bg-n-solid-2 outline outline-1 outline-n-container"
      >
        <div class="rounded-full size-12 bg-n-alpha-2 animate-pulse" />
        <div class="flex flex-col flex-1 gap-3">
          <div class="w-48 h-4 rounded bg-n-alpha-2 animate-pulse" />
          <div class="w-3/4 h-3 rounded bg-n-alpha-2 animate-pulse" />
        </div>
        <div class="w-8 h-8 rounded-lg bg-n-alpha-2 animate-pulse" />
      </div>
    </div>
  </div>
</template>
