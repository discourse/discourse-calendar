import Component from "@ember/component";
import { readOnly } from "@ember/object/computed";
import { action, computed } from "@ember/object";

export default Component.extend({
  tagName: "",
  viewingType: readOnly("modal.type"),
  isGoing: computed("viewingType", function () {
    return this.viewingType === "going" ? " btn-danger" : " btn-default";
  }),
  isInterested: computed("viewingType", function () {
    return this.viewingType === "interested" ? " btn-danger" : " btn-default";
  }),
  isNotGoing: computed("viewingType", function () {
    return this.viewingType === "not_going" ? " btn-danger" : " btn-default";
  }),

  @action
  toggleType(type) {
    this.toggle(type);
  },
});
