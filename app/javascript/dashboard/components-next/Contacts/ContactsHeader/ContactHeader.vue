<script setup>
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ContactSortMenu from './components/ContactSortMenu.vue';
import ContactsViewToggle from './components/ContactsViewToggle.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';

defineProps({
  showSearch: { type: Boolean, default: true },
  searchValue: { type: String, default: '' },
  headerTitle: { type: String, required: true },
  buttonLabel: { type: String, default: '' },
  activeSort: { type: String, default: 'last_activity_at' },
  activeOrdering: { type: String, default: '' },
  isSegmentsView: { type: Boolean, default: false },
  hasActiveFilters: { type: Boolean, default: false },
  isLabelView: { type: Boolean, default: false },
  isActiveView: { type: Boolean, default: false },
  viewMode: { type: String, default: 'table' },
  showViewToggle: { type: Boolean, default: true },
});

const emit = defineEmits([
  'search',
  'filter',
  'update:sort',
  'add',
  'import',
  'export',
  'createSegment',
  'deleteSegment',
  'update:viewMode',
]);
</script>

<template>
  <header
    class="sticky top-0 z-10 border-b bg-n-surface-1/95 border-n-weak backdrop-blur"
  >
    <div class="flex flex-col w-full gap-2 px-4 py-2 mx-auto sm:px-6 lg:px-8">
      <div
        class="grid items-center w-full gap-3 lg:grid-cols-[minmax(12rem,1fr)_minmax(18rem,34rem)_auto]"
      >
        <span
          dir="auto"
          class="min-w-0 text-xl font-semibold truncate text-start text-n-slate-12"
        >
          {{ headerTitle }}
        </span>
        <div
          v-if="showSearch"
          class="relative flex items-center w-full gap-2 lg:justify-self-center"
        >
          <Input
            :model-value="searchValue"
            type="search"
            :placeholder="$t('CONTACTS_LAYOUT.HEADER.SEARCH_PLACEHOLDER')"
            :custom-input-class="[
              'h-9 rounded-lg bg-n-alpha-2 dark:bg-n-solid-1 border-n-weak focus:!border-n-brand ltr:!pl-9 rtl:!pr-9 ltr:!pr-8 rtl:!pl-8 !py-1.5',
            ]"
            class="w-full"
            @input="emit('search', $event.target.value)"
          >
            <template #prefix>
              <Icon
                icon="i-lucide-search"
                class="absolute -translate-y-1/2 text-n-slate-11 size-4 top-1/2 ltr:left-2 rtl:right-2"
              />
            </template>
          </Input>
          <Button
            v-if="searchValue"
            v-tooltip.bottom="$t('CONTACTS_LAYOUT.HEADER.CLEAR_SEARCH')"
            :aria-label="$t('CONTACTS_LAYOUT.HEADER.CLEAR_SEARCH')"
            icon="i-lucide-x"
            color="slate"
            size="xs"
            variant="ghost"
            class="absolute -translate-y-1/2 top-1/2 ltr:right-1 rtl:left-1 !size-6"
            type="button"
            @click="emit('search', '')"
          />
        </div>
        <ComposeConversation>
          <template #trigger="{ toggle }">
            <Button
              :label="buttonLabel"
              icon="i-lucide-message-square-plus"
              size="sm"
              class="!h-9 justify-self-start lg:justify-self-end"
              @click="toggle"
            />
          </template>
        </ComposeConversation>
      </div>

      <div
        class="flex flex-col w-full gap-2 xl:flex-row xl:items-center xl:justify-between"
      >
        <div class="flex flex-wrap items-center gap-1">
          <Button
            :label="
              $t(
                'CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.ADD_CONTACT_SHORT'
              )
            "
            icon="i-lucide-plus"
            color="slate"
            size="sm"
            variant="solid"
            class="!h-8"
            @click="emit('add')"
          />
          <div
            class="inline-flex items-center h-8 gap-0.5 p-0.5 border rounded-lg border-n-weak bg-n-alpha-1"
          >
            <Button
              v-tooltip.bottom="
                $t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.IMPORT_CONTACT'
                )
              "
              :aria-label="
                $t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.IMPORT_CONTACT'
                )
              "
              icon="i-lucide-upload"
              color="slate"
              size="sm"
              variant="ghost"
              class="!size-7"
              @click="emit('import')"
            />
            <Button
              v-tooltip.bottom="
                $t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.EXPORT_CONTACT'
                )
              "
              :aria-label="
                $t(
                  'CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.EXPORT_CONTACT'
                )
              "
              icon="i-lucide-download"
              color="slate"
              size="sm"
              variant="ghost"
              class="!size-7"
              @click="emit('export')"
            />
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-1 xl:justify-end">
          <div
            class="inline-flex items-center h-8 gap-0.5 p-0.5 border rounded-lg border-n-weak bg-n-alpha-1"
          >
            <div v-if="!isLabelView && !isActiveView" class="relative">
              <Button
                id="toggleContactsFilterButton"
                :icon="
                  isSegmentsView ? 'i-lucide-pen-line' : 'i-lucide-list-filter'
                "
                color="slate"
                size="sm"
                class="relative !size-7"
                variant="ghost"
                @click="emit('filter')"
              >
                <div
                  v-if="hasActiveFilters && !isSegmentsView"
                  class="absolute top-0 w-2 h-2 rounded-full ltr:right-0 rtl:left-0 bg-n-brand"
                />
              </Button>
              <slot name="filter" />
            </div>
            <Button
              v-if="
                hasActiveFilters &&
                !isSegmentsView &&
                !isLabelView &&
                !isActiveView
              "
              icon="i-lucide-save"
              color="slate"
              size="sm"
              variant="ghost"
              class="!size-7"
              @click="emit('createSegment')"
            />
            <Button
              v-if="isSegmentsView && !isLabelView && !isActiveView"
              icon="i-lucide-trash"
              color="slate"
              size="sm"
              variant="ghost"
              class="!size-7"
              @click="emit('deleteSegment')"
            />
            <ContactSortMenu
              :active-sort="activeSort"
              :active-ordering="activeOrdering"
              @update:sort="emit('update:sort', $event)"
            />
          </div>

          <ContactsViewToggle
            v-if="showViewToggle"
            :model-value="viewMode"
            @update:model-value="emit('update:viewMode', $event)"
          />
        </div>
      </div>
    </div>
  </header>
</template>
