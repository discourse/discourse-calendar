import Controller from "@ember/controller";
import { inject } from "@ember/controller";

export default Controller.extend({
  exceptionController: inject("exception"),

  loadEvents(params) {
    this.store
      .findAll("discourse-post-event-event", params)
      .then(events => this.set("events", events))
      .catch(e => {
        this.exceptionController.set("thrown", e.jqXHR);
        this.replaceRoute("exception");
      });
  }
});
