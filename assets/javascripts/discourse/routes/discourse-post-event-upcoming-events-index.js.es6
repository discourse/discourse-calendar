import DiscourseURL from "discourse/lib/url";
import Route from "@ember/routing/route";
import { on } from "@ember/object/evented";

export default Route.extend({
  enforcePostEventEnabled: on("activate", function() {
    if (!this.siteSettings.discourse_post_event_enabled) {
      DiscourseURL.redirectTo("/404");
    }
  }),

  model(params) {
    return this.store.findAll("discourse-post-event-event", params);
  }
});
