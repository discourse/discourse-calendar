import Controller from "@ember/controller";

export default Controller.extend({
  loadEvents(params) {
    this.store
      .findAll("discourse-post-event-event", params)
      .then(events => this.set("events", events));
  }
});
