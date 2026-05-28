import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useOperators } from './operators';
import { useMapGetter } from 'dashboard/composables/store.js';
import {
  buildAttributesFilterTypes,
  CONTACT_ATTRIBUTES,
} from './helper/filterHelper.js';
import { EGYPT_GOVERNORATES } from 'dashboard/constants/egyptGovernorates';
import { EGYPT_DISTRICTS } from 'dashboard/constants/egyptDistricts';

/**
 * @typedef {Object} FilterOption
 * @property {string|number} id
 * @property {string} name
 * @property {import('vue').VNode} [icon]
 */

/**
 * @typedef {Object} FilterOperator
 * @property {string} value
 * @property {string} label
 * @property {string} icon
 * @property {boolean} hasInput
 */

/**
 * @typedef {Object} FilterType
 * @property {string} attributeKey - The attribute key
 * @property {string} value - This is a proxy for the attribute key used in FilterSelect
 * @property {string} attributeName - The attribute name used to display on the UI
 * @property {string} label - This is a proxy for the attribute name used in FilterSelect
 * @property {'multiSelect'|'searchSelect'|'plainText'|'date'|'booleanSelect'} inputType - The input type for the attribute
 * @property {FilterOption[]} [options] - The options available for the attribute if it is a multiSelect or singleSelect type
 * @property {'text'|'number'} dataType
 * @property {FilterOperator[]} filterOperators - The operators available for the attribute
 * @property {'standard'|'additional'|'customAttributes'} attributeModel
 */

/**
 * @typedef {Object} FilterGroup
 * @property {string} name
 * @property {FilterType[]} attributes
 */

/**
 * Composable that provides conversation filtering context
 * @returns {{ filterTypes: import('vue').ComputedRef<FilterType[]>, filterGroups: import('vue').ComputedRef<FilterGroup[]> }}
 */
export function useContactFilterContext() {
  const { t } = useI18n();

  const contactAttributes = useMapGetter('attributes/getContactAttributes');
  const labels = useMapGetter('labels/getLabels');

  const {
    equalityOperators,
    containmentOperators,
    dateOperators,
    getOperatorTypes,
  } = useOperators();

  /**
   * @type {import('vue').ComputedRef<FilterType[]>}
   */
  const customFilterTypes = computed(() =>
    buildAttributesFilterTypes(
      contactAttributes.value,
      getOperatorTypes,
      'contact'
    )
  );

  /**
   * @type {import('vue').ComputedRef<FilterType[]>}
   */
  const filterTypes = computed(() => [
    {
      attributeKey: CONTACT_ATTRIBUTES.NAME,
      value: CONTACT_ATTRIBUTES.NAME,
      attributeName: t('CONTACTS_LAYOUT.FILTER.NAME'),
      label: t('CONTACTS_LAYOUT.FILTER.NAME'),
      inputType: 'plainText',
      dataType: 'text',
      filterOperators: equalityOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.EMAIL,
      value: CONTACT_ATTRIBUTES.EMAIL,
      attributeName: t('CONTACTS_LAYOUT.FILTER.EMAIL'),
      label: t('CONTACTS_LAYOUT.FILTER.EMAIL'),
      inputType: 'plainText',
      dataType: 'text',
      filterOperators: containmentOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.PHONE_NUMBER,
      value: CONTACT_ATTRIBUTES.PHONE_NUMBER,
      attributeName: t('CONTACTS_LAYOUT.FILTER.PHONE_NUMBER'),
      label: t('CONTACTS_LAYOUT.FILTER.PHONE_NUMBER'),
      inputType: 'plainText',
      dataType: 'text',
      filterOperators: containmentOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.IDENTIFIER,
      value: CONTACT_ATTRIBUTES.IDENTIFIER,
      attributeName: t('CONTACTS_LAYOUT.FILTER.IDENTIFIER'),
      label: t('CONTACTS_LAYOUT.FILTER.IDENTIFIER'),
      inputType: 'plainText',
      dataType: 'number',
      filterOperators: equalityOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.CREATED_AT,
      value: CONTACT_ATTRIBUTES.CREATED_AT,
      attributeName: t('CONTACTS_LAYOUT.FILTER.CREATED_AT'),
      label: t('CONTACTS_LAYOUT.FILTER.CREATED_AT'),
      inputType: 'date',
      dataType: 'text',
      filterOperators: dateOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.LAST_ACTIVITY_AT,
      value: CONTACT_ATTRIBUTES.LAST_ACTIVITY_AT,
      attributeName: t('CONTACTS_LAYOUT.FILTER.LAST_ACTIVITY'),
      label: t('CONTACTS_LAYOUT.FILTER.LAST_ACTIVITY'),
      inputType: 'date',
      dataType: 'text',
      filterOperators: dateOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.BLOCKED,
      value: CONTACT_ATTRIBUTES.BLOCKED,
      attributeName: t('CONTACTS_LAYOUT.FILTER.BLOCKED'),
      label: t('CONTACTS_LAYOUT.FILTER.BLOCKED'),
      inputType: 'searchSelect',
      options: [
        {
          id: 'true',
          name: t('CONTACTS_LAYOUT.FILTER.BLOCKED_TRUE'),
        },
        {
          id: 'false',
          name: t('CONTACTS_LAYOUT.FILTER.BLOCKED_FALSE'),
        },
      ],
      dataType: 'text',
      filterOperators: equalityOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.LABELS,
      value: CONTACT_ATTRIBUTES.LABELS,
      attributeName: t('CONTACTS_FILTER.ATTRIBUTES.LABELS'),
      label: t('CONTACTS_FILTER.ATTRIBUTES.LABELS'),
      inputType: 'multiSelect',
      options: labels.value?.map(label => ({
        id: label.title,
        name: label.title,
      })),
      dataType: 'text',
      filterOperators: equalityOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.CUSTOMER_CLASSIFICATION,
      value: CONTACT_ATTRIBUTES.CUSTOMER_CLASSIFICATION,
      attributeName: t('CONTACTS_LAYOUT.FILTER.CUSTOMER_CLASSIFICATION'),
      label: t('CONTACTS_LAYOUT.FILTER.CUSTOMER_CLASSIFICATION'),
      inputType: 'searchSelect',
      options: [
        {
          id: 'Library',
          name: t(
            'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.LIBRARY'
          ),
        },
        {
          id: 'Teacher',
          name: t(
            'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.TEACHER'
          ),
        },
        {
          id: 'Student',
          name: t(
            'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.STUDENT'
          ),
        },
        {
          id: 'Center',
          name: t(
            'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.CENTER'
          ),
        },
        {
          id: 'Other',
          name: t(
            'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.CLASSIFICATION_OPTIONS.OTHER'
          ),
        },
      ],
      dataType: 'text',
      filterOperators: equalityOperators.value,
      attributeModel: 'additional',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.LIBRARY_CLASSIFICATION,
      value: CONTACT_ATTRIBUTES.LIBRARY_CLASSIFICATION,
      attributeName: t('CONTACTS_LAYOUT.FILTER.LIBRARY_CLASSIFICATION'),
      label: t('CONTACTS_LAYOUT.FILTER.LIBRARY_CLASSIFICATION'),
      inputType: 'searchSelect',
      options: [
        {
          id: 'قطاعي',
          name: t(
            'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.LIBRARY_CLASSIFICATION_OPTIONS.SECTOR'
          ),
        },
        {
          id: 'جملة',
          name: t(
            'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.LIBRARY_CLASSIFICATION_OPTIONS.WHOLESALE'
          ),
        },
      ],
      dataType: 'text',
      filterOperators: equalityOperators.value,
      attributeModel: 'additional',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.ERP_LINK_STATUS,
      value: CONTACT_ATTRIBUTES.ERP_LINK_STATUS,
      attributeName: t('CONTACTS_LAYOUT.FILTER.ERP_LINK_STATUS'),
      label: t('CONTACTS_LAYOUT.FILTER.ERP_LINK_STATUS'),
      inputType: 'searchSelect',
      options: [
        { id: 'linked', name: t('CONTACTS_LAYOUT.FILTER.ERP_STATUS_LINKED') },
        {
          id: 'unlinked',
          name: t('CONTACTS_LAYOUT.FILTER.ERP_STATUS_UNLINKED'),
        },
        {
          id: 'sync_required',
          name: t('CONTACTS_LAYOUT.FILTER.ERP_STATUS_SYNC_REQUIRED'),
        },
        {
          id: 'sync_failed',
          name: t('CONTACTS_LAYOUT.FILTER.ERP_STATUS_SYNC_FAILED'),
        },
      ],
      dataType: 'text',
      filterOperators: equalityOperators.value,
      attributeModel: 'additional',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.ADDRESS_GOVERNORATE,
      value: CONTACT_ATTRIBUTES.ADDRESS_GOVERNORATE,
      attributeName: t('CONTACTS_LAYOUT.FILTER.ADDRESS_GOVERNORATE'),
      label: t('CONTACTS_LAYOUT.FILTER.ADDRESS_GOVERNORATE'),
      inputType: 'searchSelect',
      options: EGYPT_GOVERNORATES.map(g => ({ id: g.value, name: g.label })),
      dataType: 'text',
      filterOperators: equalityOperators.value,
      attributeModel: 'additional',
    },
    {
      attributeKey: CONTACT_ATTRIBUTES.ADDRESS_DISTRICT,
      value: CONTACT_ATTRIBUTES.ADDRESS_DISTRICT,
      attributeName: t('CONTACTS_LAYOUT.FILTER.ADDRESS_DISTRICT'),
      label: t('CONTACTS_LAYOUT.FILTER.ADDRESS_DISTRICT'),
      inputType: 'searchSelect',
      options: EGYPT_DISTRICTS.map(d => ({ id: d.value, name: d.label })),
      dataType: 'text',
      filterOperators: equalityOperators.value,
      attributeModel: 'additional',
    },
    ...customFilterTypes.value,
  ]);

  return { filterTypes };
}
