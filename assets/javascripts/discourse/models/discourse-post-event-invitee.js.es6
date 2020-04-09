import RestModel from "discourse/models/rest";

export default RestModel.extend({
  init() {
    this._super(...arguments);

    this.__type = "discourse-post-event-invitee";
  }
});
