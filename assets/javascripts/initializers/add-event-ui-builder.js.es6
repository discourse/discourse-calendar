import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";
import { Promise } from "rsvp";

function initializeEventUIBuilder(api) {
  api.attachWidgetAction("post", "showEventUIBuilder", function({
    postId,
    topicId
  }) {
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
    }).then(postEvent => {
      showModal("event-ui-builder", {
        model: { postEvent, topicId },
        modalClass: "event-ui-builder-modal"
      });
    });
  });

  api.decorateWidget("post-admin-menu:after", dec => {
    return dec.attach("post-admin-menu-button", {
      icon: "calendar-day",
      label: "event.ui_builder.attach",
      action: "showEventUIBuilder",
      actionParam: { postId: dec.attrs.id, topicId: dec.attrs.topicId }
    });
  });
}

export default {
  name: "add-event-ui-builder",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.post_event_enabled) {
      withPluginApi("0.8.7", initializeEventUIBuilder);
    }
  }
};
