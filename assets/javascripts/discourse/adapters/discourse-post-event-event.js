import { underscore } from "@ember/string";
import DiscoursePostEventAdapter from "./discourse-post-event-adapter";

export default DiscoursePostEventAdapter.extend({
  pathFor(store, type, findArgs) {
    const path =
      this.basePath(store, type, findArgs) +
      underscore(store.pluralize(this.apiNameFor(type)));
    return this.appendQueryParams(path, findArgs);
  },

  apiNameFor() {
    return "event";
  },
});
