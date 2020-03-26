import Controller from "@ember/controller";

export default Controller.extend({
  loadPostEvents(params) {
    this.store.findAll("post-event", params).then(postEvents => {
      this.set("postEvents", postEvents);
    });
  }
});
