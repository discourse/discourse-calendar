import DiscoursePostEventAdapter from "./discourse-post-event-adapter";
import { underscore } from "@ember/string";

export default DiscoursePostEventAdapter.extend({
  pathFor(store, type, findArgs) {
    let path =
      this.basePath(store, type, findArgs) +
      underscore(store.pluralize(this.apiNameFor(type)));
    return this.appendQueryParams(path, findArgs);
  },

  apiNameFor() {
    return "invitee";
  }
});
