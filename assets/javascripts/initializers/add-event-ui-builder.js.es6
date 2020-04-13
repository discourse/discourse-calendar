import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";

function initializeEventBuilder(api) {
  const currentUser = api.getCurrentUser();

  api.onToolbarCreate(toolbar => {
    if (
      !currentUser ||
      !currentUser.can_create_event ||
      !toolbar.context.outletArgs
    ) {
      return;
    }

    const composer = toolbar.context.outletArgs.composer;
    if (
      !composer.replyingToTopic &&
      (composer.topicFirstPost ||
        (composer.editingPost &&
          composer.post &&
          composer.post.post_number === 1))
    ) {
      toolbar.addButton({
        title: "discourse_post_event.builder_modal.attach",
        id: "insertEvent",
        group: "insertions",
        icon: "calendar-day",
        perform: toolbarEvent => {
          const eventModel = toolbar.context.store.createRecord(
            "discourse-post-event-event"
          );
          eventModel.setProperties({
            status: "public"
          });

          showModal("discourse-post-event-builder").setProperties({
            toolbarEvent,
            model: { eventModel }
          });
        }
      });
    }
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
