import DiscourseURL from "discourse/lib/url";
import Route from "@ember/routing/route";
import { on } from "@ember/object/evented";

export default Route.extend({
  queryParams: {
    invited: { refreshModel: true, replace: true }
  },

  enforcePostEventEnabled: on("activate", function() {
    if (!this.siteSettings.post_event_enabled) {
      DiscourseURL.redirectTo("/404");
    }
  }),

  model(params) {
    return params;
  },

  setupController(controller, params) {
    controller.loadPostEvents(params);
  }
});
