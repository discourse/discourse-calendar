import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";

export default class PostEventUpcomingEventsIndexRoute extends DiscourseRoute {
  @service discoursePostEventApi;

  @action
  activate() {
    if (!this.siteSettings.discourse_post_event_enabled) {
      DiscourseURL.redirectTo("/404");
    }
  }

  async model(params) {
    if (this.siteSettings.include_expired_events_on_calendar) {
      params.include_expired = true;
    }

    return await this.discoursePostEventApi.events(params);
  }
}
