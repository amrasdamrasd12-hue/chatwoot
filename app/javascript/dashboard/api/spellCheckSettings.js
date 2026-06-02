/* global axios */
import ApiClient from './ApiClient';

// Eltafouk: account-scoped CRUD for the pre-send spell-check guard
// settings (DM toggle, comments toggle, long-message strategy).
class SpellCheckSettings extends ApiClient {
  constructor() {
    super('spell_check_settings', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  update(settings) {
    return axios.patch(this.url, { settings });
  }
}

export default new SpellCheckSettings();
