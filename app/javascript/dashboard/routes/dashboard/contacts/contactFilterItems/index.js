import {
  OPERATOR_TYPES_1,
  OPERATOR_TYPES_2,
  OPERATOR_TYPES_3,
  OPERATOR_TYPES_5,
} from 'dashboard/components/widgets/FilterInput/FilterOperatorTypes.js';
const filterTypes = [
  {
    attributeKey: 'name',
    attributeI18nKey: 'NAME',
    inputType: 'plain_text',
    dataType: 'text',
    filterOperators: OPERATOR_TYPES_1,
    attribute_type: 'standard',
  },
  {
    attributeKey: 'email',
    attributeI18nKey: 'EMAIL',
    inputType: 'plain_text',
    dataType: 'text',
    filterOperators: OPERATOR_TYPES_3,
    attribute_type: 'standard',
  },
  {
    attributeKey: 'phone_number',
    attributeI18nKey: 'PHONE_NUMBER',
    inputType: 'plain_text',
    dataType: 'text',
    filterOperators: OPERATOR_TYPES_3,
    attribute_type: 'standard',
  },
  {
    attributeKey: 'identifier',
    attributeI18nKey: 'IDENTIFIER',
    inputType: 'plain_text',
    dataType: 'number',
    filterOperators: OPERATOR_TYPES_1,
    attribute_type: 'standard',
  },
  {
    attributeKey: 'created_at',
    attributeI18nKey: 'CREATED_AT',
    inputType: 'date',
    dataType: 'text',
    filterOperators: OPERATOR_TYPES_5,
    attributeModel: 'standard',
  },
  {
    attributeKey: 'last_activity_at',
    attributeI18nKey: 'LAST_ACTIVITY',
    inputType: 'date',
    dataType: 'text',
    filterOperators: OPERATOR_TYPES_5,
    attributeModel: 'standard',
  },
  {
    attributeKey: 'blocked',
    attributeI18nKey: 'BLOCKED',
    inputType: 'search_select',
    dataType: 'text',
    filterOperators: OPERATOR_TYPES_1,
    attributeModel: 'standard',
  },
  {
    attributeKey: 'labels',
    attributeI18nKey: 'LABELS',
    inputType: 'multi_select',
    dataType: 'text',
    filterOperators: OPERATOR_TYPES_2,
    attributeModel: 'standard',
  },
  {
    attributeKey: 'custom_customer_classification',
    attributeI18nKey: 'CUSTOMER_CLASSIFICATION',
    inputType: 'search_select',
    dataType: 'text',
    filterOperators: OPERATOR_TYPES_1,
    attributeModel: 'additional',
  },
  {
    attributeKey: 'custom_library_classification',
    attributeI18nKey: 'LIBRARY_CLASSIFICATION',
    inputType: 'search_select',
    dataType: 'text',
    filterOperators: OPERATOR_TYPES_1,
    attributeModel: 'additional',
  },
  {
    attributeKey: 'erp_link_status',
    attributeI18nKey: 'ERP_LINK_STATUS',
    inputType: 'search_select',
    dataType: 'text',
    filterOperators: OPERATOR_TYPES_1,
    attributeModel: 'additional',
  },
  {
    attributeKey: 'address_governorate',
    attributeI18nKey: 'ADDRESS_GOVERNORATE',
    inputType: 'search_select',
    dataType: 'text',
    filterOperators: OPERATOR_TYPES_1,
    attributeModel: 'additional',
  },
  {
    attributeKey: 'address_district',
    attributeI18nKey: 'ADDRESS_DISTRICT',
    inputType: 'search_select',
    dataType: 'text',
    filterOperators: OPERATOR_TYPES_1,
    attributeModel: 'additional',
  },
];

export const filterAttributeGroups = [
  {
    name: 'Standard Filters',
    i18nGroup: 'STANDARD_FILTERS',
    attributes: [
      {
        key: 'name',
        i18nKey: 'NAME',
      },
      {
        key: 'email',
        i18nKey: 'EMAIL',
      },
      {
        key: 'phone_number',
        i18nKey: 'PHONE_NUMBER',
      },
      {
        key: 'identifier',
        i18nKey: 'IDENTIFIER',
      },
      {
        key: 'created_at',
        i18nKey: 'CREATED_AT',
      },
      {
        key: 'last_activity_at',
        i18nKey: 'LAST_ACTIVITY',
      },
      {
        key: 'blocked',
        i18nKey: 'BLOCKED',
      },
      {
        key: 'labels',
        i18nKey: 'LABELS',
      },
      {
        key: 'custom_customer_classification',
        i18nKey: 'CUSTOMER_CLASSIFICATION',
      },
      {
        key: 'custom_library_classification',
        i18nKey: 'LIBRARY_CLASSIFICATION',
      },
      {
        key: 'erp_link_status',
        i18nKey: 'ERP_LINK_STATUS',
      },
      {
        key: 'address_governorate',
        i18nKey: 'ADDRESS_GOVERNORATE',
      },
      {
        key: 'address_district',
        i18nKey: 'ADDRESS_DISTRICT',
      },
    ],
  },
];

export default filterTypes;
