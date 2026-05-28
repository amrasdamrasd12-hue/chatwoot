import {
  DuplicateContactException,
  DuplicatePhoneException,
  ExceptionWithMessage,
} from 'shared/helpers/CustomErrors';
import types from '../../mutation-types';
import ContactAPI from '../../../api/contacts';
import snakecaseKeys from 'snakecase-keys';
import AccountActionsAPI from '../../../api/accountActions';
import AnalyticsHelper from '../../../helper/AnalyticsHelper';
import { CONTACTS_EVENTS } from '../../../helper/AnalyticsHelper/events';
import { downloadBlobFile } from '../../../helper/downloadHelper';

const buildContactFormData = contactParams => {
  const formData = new FormData();
  const { additional_attributes = {}, ...contactProperties } = contactParams;
  Object.keys(contactProperties).forEach(key => {
    if (contactProperties[key]) {
      formData.append(key, contactProperties[key]);
    }
  });
  const { social_profiles, ...additionalAttributesProperties } =
    additional_attributes;
  Object.keys(additionalAttributesProperties).forEach(key => {
    formData.append(
      `additional_attributes[${key}]`,
      additionalAttributesProperties[key]
    );
  });
  Object.keys(social_profiles || {}).forEach(key => {
    formData.append(
      `additional_attributes[social_profiles][${key}]`,
      social_profiles[key]
    );
  });
  return formData;
};

export const handleContactOperationErrors = error => {
  if (error.response?.status === 422) {
    const { message, attributes, error_type } = error.response.data || {};
    if (error_type === 'phone_duplicate') {
      throw new DuplicatePhoneException(message);
    }
    if (attributes?.includes('base') && message) {
      throw new ExceptionWithMessage(message);
    }
    throw new DuplicateContactException(attributes);
  } else if (error.response?.data?.message) {
    throw new ExceptionWithMessage(error.response.data.message);
  } else {
    throw new Error(error);
  }
};

export const actions = {
  search: async (
    { commit },
    { search, page, sortAttr, label, append = false, perPage }
  ) => {
    commit(types.SET_CONTACT_UI_FLAG, { isFetching: true });
    try {
      const {
        data: { payload, meta },
      } = await ContactAPI.search(search, page, sortAttr, label, perPage);
      if (!append) {
        commit(types.CLEAR_CONTACTS);
      }
      commit(append ? types.APPEND_CONTACTS : types.SET_CONTACTS, payload);
      commit(types.SET_CONTACT_META, meta);
      commit(types.SET_CONTACT_UI_FLAG, { isFetching: false });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isFetching: false });
      throw new Error(error);
    }
  },

  get: async ({ commit }, { page = 1, sortAttr, label, perPage } = {}) => {
    commit(types.SET_CONTACT_UI_FLAG, { isFetching: true });
    try {
      const {
        data: { payload, meta },
      } = await ContactAPI.get(page, sortAttr, label, perPage);
      commit(types.CLEAR_CONTACTS);
      commit(types.SET_CONTACTS, payload);
      commit(types.SET_CONTACT_META, meta);
      commit(types.SET_CONTACT_UI_FLAG, { isFetching: false });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isFetching: false });
      throw new Error(error);
    }
  },

  active: async ({ commit }, { page = 1, sortAttr, perPage } = {}) => {
    commit(types.SET_CONTACT_UI_FLAG, { isFetching: true });
    try {
      const {
        data: { payload, meta },
      } = await ContactAPI.active(page, sortAttr, perPage);
      commit(types.CLEAR_CONTACTS);
      commit(types.SET_CONTACTS, payload);
      commit(types.SET_CONTACT_META, meta);
      commit(types.SET_CONTACT_UI_FLAG, { isFetching: false });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isFetching: false });
      throw new Error(error);
    }
  },

  show: async ({ commit }, { id }) => {
    commit(types.SET_CONTACT_UI_FLAG, { isFetchingItem: true });
    try {
      const response = await ContactAPI.show(id);
      commit(types.SET_CONTACT_ITEM, response.data.payload);
      commit(types.SET_CONTACT_UI_FLAG, {
        isFetchingItem: false,
      });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, {
        isFetchingItem: false,
      });
      throw new Error(error);
    }
  },

  update: async ({ commit }, { id, isFormData = false, ...contactParams }) => {
    const { avatar, customAttributes, ...paramsToDecamelize } = contactParams;
    const decamelizedContactParams = {
      ...snakecaseKeys(paramsToDecamelize, { deep: true }),
      ...(customAttributes && { custom_attributes: customAttributes }),
      ...(avatar && { avatar }),
    };
    commit(types.SET_CONTACT_UI_FLAG, { isUpdating: true });
    try {
      const response = await ContactAPI.update(
        id,
        isFormData
          ? buildContactFormData(decamelizedContactParams)
          : decamelizedContactParams
      );
      commit(types.EDIT_CONTACT, response.data.payload);
      commit(types.SET_CONTACT_UI_FLAG, { isUpdating: false });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isUpdating: false });
      handleContactOperationErrors(error);
    }
  },

  create: async ({ commit }, { isFormData = false, ...contactParams }) => {
    const decamelizedContactParams = snakecaseKeys(contactParams, {
      deep: true,
    });
    commit(types.SET_CONTACT_UI_FLAG, { isCreating: true });
    try {
      const response = await ContactAPI.create(
        isFormData
          ? buildContactFormData(decamelizedContactParams)
          : decamelizedContactParams
      );

      AnalyticsHelper.track(CONTACTS_EVENTS.CREATE_CONTACT);
      commit(types.SET_CONTACT_ITEM, response.data.payload.contact);
      commit(types.SET_CONTACT_UI_FLAG, { isCreating: false });
      return response.data.payload.contact;
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isCreating: false });
      return handleContactOperationErrors(error);
    }
  },

  import: async ({ commit }, file) => {
    commit(types.SET_CONTACT_UI_FLAG, { isImporting: true });
    try {
      const response = await ContactAPI.importContacts(file);
      commit(types.SET_CONTACT_UI_FLAG, { isImporting: false });
      return response.data?.payload;
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isImporting: false });
      const errorMessage =
        error.response?.data?.message || error.response?.data?.error;
      if (errorMessage) {
        throw new ExceptionWithMessage(errorMessage);
      }
      throw new Error(error);
    }
  },

  export: async ({ commit }, { payload, label, columnNames, selectedIds }) => {
    commit(types.SET_CONTACT_UI_FLAG, { isExporting: true });
    try {
      const response = await ContactAPI.exportContacts({
        payload,
        label,
        column_names: columnNames,
        selected_ids: selectedIds,
      });
      downloadBlobFile(
        'contacts_export.xlsx',
        response.data,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      );
      commit(types.SET_CONTACT_UI_FLAG, { isExporting: false });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isExporting: false });
      if (error.response?.data?.message) {
        throw new Error(error.response.data.message);
      } else {
        throw new Error(error);
      }
    }
  },

  delete: async ({ commit }, id) => {
    commit(types.SET_CONTACT_UI_FLAG, { isDeleting: true });
    try {
      await ContactAPI.delete(id);
      commit(types.SET_CONTACT_UI_FLAG, { isDeleting: false });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isDeleting: false });
      if (error.response?.data?.message) {
        throw new Error(error.response.data.message);
      } else {
        throw new Error(error);
      }
    }
  },

  deleteCustomAttributes: async ({ commit }, { id, customAttributes }) => {
    try {
      const response = await ContactAPI.destroyCustomAttributes(
        id,
        customAttributes
      );
      commit(types.EDIT_CONTACT, response.data.payload);
    } catch (error) {
      throw new Error(error);
    }
  },

  deleteAvatar: async ({ commit }, id) => {
    try {
      const response = await ContactAPI.destroyAvatar(id);
      commit(types.EDIT_CONTACT, response.data.payload);
    } catch (error) {
      throw new Error(error);
    }
  },

  fetchContactableInbox: async ({ commit }, id) => {
    commit(types.SET_CONTACT_UI_FLAG, { isFetchingInboxes: true });
    try {
      const response = await ContactAPI.getContactableInboxes(id);
      const contact = {
        id: Number(id),
        contact_inboxes: response.data.payload,
      };
      commit(types.SET_CONTACT_ITEM, contact);
    } catch (error) {
      if (error.response?.data?.message) {
        throw new ExceptionWithMessage(error.response.data.message);
      } else {
        throw new Error(error);
      }
    } finally {
      commit(types.SET_CONTACT_UI_FLAG, { isFetchingInboxes: false });
    }
  },

  updatePresence: ({ commit }, data) => {
    commit(types.UPDATE_CONTACTS_PRESENCE, data);
  },

  setContact({ commit }, data) {
    commit(types.SET_CONTACT_ITEM, data);
  },

  merge: async ({ commit }, { childId, parentId }) => {
    commit(types.SET_CONTACT_UI_FLAG, { isMerging: true });
    try {
      const response = await AccountActionsAPI.merge(parentId, childId);
      commit(types.SET_CONTACT_ITEM, response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_CONTACT_UI_FLAG, { isMerging: false });
    }
  },

  deleteContactThroughConversations: ({ commit }, id) => {
    commit(types.DELETE_CONTACT, id);
    commit(types.CLEAR_CONTACT_CONVERSATIONS, id, { root: true });
    commit(`contactConversations/${types.DELETE_CONTACT_CONVERSATION}`, id, {
      root: true,
    });
  },

  updateContact: async ({ commit }, updateObj) => {
    commit(types.SET_CONTACT_UI_FLAG, { isUpdating: true });
    try {
      commit(types.EDIT_CONTACT, updateObj);
      commit(types.SET_CONTACT_UI_FLAG, { isUpdating: false });
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isUpdating: false });
    }
  },

  filter: async (
    { commit },
    { page = 1, sortAttr, queryPayload, resetState = true, perPage } = {}
  ) => {
    commit(types.SET_CONTACT_UI_FLAG, { isFetching: true });
    try {
      const {
        data: { payload, meta },
      } = await ContactAPI.filter(page, sortAttr, queryPayload, perPage);
      if (resetState) {
        commit(types.CLEAR_CONTACTS);
        commit(types.SET_CONTACTS, payload);
        commit(types.SET_CONTACT_META, meta);
        commit(types.SET_CONTACT_UI_FLAG, { isFetching: false });
      }
      return payload;
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isFetching: false });
      throw new Error(error);
    }
  },

  setContactFilters({ commit }, data) {
    commit(types.SET_CONTACT_FILTERS, data);
  },

  clearContactFilters({ commit }) {
    commit(types.CLEAR_CONTACT_FILTERS);
  },

  initiateCall: async ({ commit }, { contactId, inboxId }) => {
    commit(types.SET_CONTACT_UI_FLAG, { isInitiatingCall: true });
    try {
      const response = await ContactAPI.initiateCall(contactId, inboxId);
      commit(types.SET_CONTACT_UI_FLAG, { isInitiatingCall: false });
      return response.data;
    } catch (error) {
      commit(types.SET_CONTACT_UI_FLAG, { isInitiatingCall: false });
      if (error.response?.data?.message) {
        throw new ExceptionWithMessage(error.response.data.message);
      } else if (error.response?.data?.error) {
        throw new ExceptionWithMessage(error.response.data.error);
      } else {
        throw new Error(error);
      }
    }
  },
};
