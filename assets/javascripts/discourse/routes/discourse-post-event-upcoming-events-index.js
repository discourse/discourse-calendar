import { on } from "@ember/object/evented";
import Route from "@ember/routing/route";
import DiscourseURL from "discourse/lib/url";

export default Route.extend({
  enforcePostEventEnabled: on("activate", function () {
    if (!this.siteSettings.discourse_post_event_enabled) {
      DiscourseURL.redirectTo("/404");
    }
  }),

  model(params) {
    alert("HERE?")
    return this.store.findAll("discourse-post-event-event", params);
  },
});
