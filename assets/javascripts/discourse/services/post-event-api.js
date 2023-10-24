import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";

/**
 * Discourse Post Event API Service
 *
 * @implements {@ember/service}
 */
export default class PostEventApi extends Service {
  /**
   *
   * @param {number} categoryId - ID of the category to fetch events from
   *
   * @returns {Promise}
   */
  categoryEvents(categoryId) {
    return this.#getRequest("/events", { category_id: categoryId });
  }

  get #basePath() {
    return "/discourse-post-event";
  }

  #getRequest(endpoint, data = {}) {
    return ajax(`${this.#basePath}${endpoint}`, {
      type: "GET",
      data,
    });
  }
}
