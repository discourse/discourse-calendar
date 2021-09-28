import Component from "@ember/component";
import { readOnly } from "@ember/object/computed";
import { action, computed } from "@ember/object";

export default Component.extend({
  tagName: "",
  viewingType: readOnly("modal.type"),

  @discourseComputed("viewingType")
  isGoing(viewingType) {
    return viewingType === "going" ? " btn-danger" : " btn-default";
  },

  @discourseComputed("viewingType")
  isInterested(viewingType) {
    return viewingType === "interested" ? " btn-danger" : " btn-default";
  },

  @discourseComputed("viewingType")
  isNotGoing(viewingType) {
    return viewingType === "not_going" ? " btn-danger" : " btn-default";
  },

  @action
  toggleType(type) {
    this.toggle(type);
  },
});
