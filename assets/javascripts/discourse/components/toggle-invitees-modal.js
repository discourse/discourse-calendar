import Component from "@ember/component";
import { readOnly } from "@ember/object/computed";
import { computed, action } from "@ember/object";

export default Component.extend({
  tagName: "",
  viewingGoing: readOnly("modal.viewingGoing"),
  viewingInterested: readOnly("modal.viewingInterested"),
  viewingNotGoing: readOnly("modal.viewingNotGoing"),
  isGoing: computed("viewingGoing", function () {
    return this.viewingGoing ? " btn-danger" : " btn-default";
  }),
  isInterested: computed("viewingInterested", function () {
    return this.viewingInterested ? " btn-danger" : " btn-default";
  }),
  isNotGoing: computed("viewingNotGoing", function () {
    return this.viewingNotGoing ? " btn-danger" : " btn-default";
  }),

  @action
  toggleViewing(type) {
    console.log("clicked");
    this.toggle(type);
  },
});
