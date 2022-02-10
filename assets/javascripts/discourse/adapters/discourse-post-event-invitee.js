import DiscoursePostEventNestedAdapter from "./discourse-post-event-nested-adapter";

export default DiscoursePostEventNestedAdapter.extend({
  apiNameFor() {
    return "invitee";
  },
});
