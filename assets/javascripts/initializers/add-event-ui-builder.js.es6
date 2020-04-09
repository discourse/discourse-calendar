import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";
import { Promise } from "rsvp";

function initializeEventBuilder(api) {
  api.attachWidgetAction("post", "showEventBuilder", function({
    postId,
    topicId
  }) {
    return new Promise(resolve => {
      if (postId) {
        this.store
          .find("discourse-post-event-event", postId)
          .then(resolve)
          .catch(() => {
            const eventModel = this.store.createRecord(
              "discourse-post-event-event"
            );
            eventModel.setProperties({
              id: postId,
              status: "public"
            });
            resolve(eventModel);
          });
      } else if (this.model) {
        resolve(this.model);
      }
    }).then(eventModel => {
      showModal("discourse-post-event-builder", {
        model: { eventModel, topicId },
        modalClass: "discourse-post-event-builder"
      });
    });
  });

  api.decorateWidget("post-admin-menu:after", dec => {
    return dec.attach("post-admin-menu-button", {
      icon: "calendar-day",
      label: "discourse_event.builder.attach",
      action: "showEventBuilder",
      actionParam: { postId: dec.attrs.id, topicId: dec.attrs.topicId }
    });
  });
}

export default {
  name: "add-discourse-post-event-builder",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.discourse_post_event_enabled) {
      withPluginApi("0.8.7", initializeEventBuilder);
    }
  }
};
