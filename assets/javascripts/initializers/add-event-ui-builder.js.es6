import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";
import { Promise } from "rsvp";

function initializeEventUIBuilder(api) {
  api.decorateWidget("hamburger-menu:generalLinks", () => {
    return {
      icon: "calendar-day",
      route: "upcoming-events",
      label: "upcoming_events.title"
    };
  });

  api.attachWidgetAction("post", "showEventUIBuilder", function(postId) {
    return new Promise(resolve => {
      if (postId) {
        this.store
          .find("post-event", postId)
          .then(resolve)
          .catch(() => {
            const postEvent = this.store.createRecord("post-event");
            postEvent.setProperties({
              id: postId,
              status: "public",
              display_invitees: "everyone"
            });
            resolve(postEvent);
          });
      } else if (this.model) {
        resolve(this.model);
      }
    }).then(model => {
      showModal("event-ui-builder", {
        model,
        modalClass: "event-ui-builder-modal"
      });
    });
  });

  api.decorateWidget("post-admin-menu:after", dec => {
    return dec.attach("post-admin-menu-button", {
      icon: "calendar-day",
      label: "event.ui_builder.attach",
      action: "showEventUIBuilder",
      actionParam: dec.attrs.id
    });
  });
}

export default {
  name: "add-event-ui-builder",

  initialize() {
    withPluginApi("0.8.7", initializeEventUIBuilder);
  }
};
