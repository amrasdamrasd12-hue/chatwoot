/* global axios */
import ApiClient from './ApiClient';

class Backups extends ApiClient {
  constructor() {
    super('backups', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create() {
    return axios.post(this.url);
  }

  delete(filename) {
    return axios.delete(`${this.url}/${filename}`);
  }

  // Stream the file as a blob so the access token travels in the request
  // header (axios default) instead of being exposed in the URL query string.
  download(filename) {
    return axios.get(`${this.url}/${filename}`, { responseType: 'blob' });
  }

  update(interval) {
    return axios.put(`${this.url}/interval`, { interval });
  }
}

export default new Backups();
