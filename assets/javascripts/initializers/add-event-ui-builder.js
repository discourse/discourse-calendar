import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";

function initializeEventBuilder(api) {
  const currentUser = api.getCurrentUser();

  api.addToolbarPopupMenuOptionsCallback((composerController) => {
    if (!currentUser || !currentUser.can_create_discourse_post_event) {
      return;
    }

    const composerModel = composerController.model;
    if (
      composerModel &&
      !composerModel.replyingToTopic &&
      (composerModel.topicFirstPost ||
        composerModel.creatingPrivateMessage ||
        (composerModel.editingPost &&
          composerModel.post &&
          composerModel.post.post_number === 1))
    ) {
      return {
        label: "discourse_post_event.builder_modal.attach",
        id: "insertEvent",
        group: "insertions",
        icon: "calendar-day",
        action: "insertEvent",
      };
    }
  });

  api.modifyClass("controller:composer", {
    pluginId: "discourse-calendar",

    actions: {
      insertEvent() {
        const eventModel = this.store.createRecord(
          "discourse-post-event-event"
        );
        eventModel.set("status", "public");
        eventModel.set("custom_fields", {});
        eventModel.set("starts_at", moment());
        eventModel.set("timezone", moment.tz.guess());

        showModal("discourse-post-event-builder").setProperties({
          toolbarEvent: this.toolbarEvent,
          model: { eventModel },
        });
      },
    },
  });
}

export default {
  name: "add-discourse-post-event-builder",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (siteSettings.discourse_post_event_enabled) {
      withPluginApi("0.8.7", initializeEventBuilder);
    }
  },
};
