import { withPluginApi } from "discourse/lib/plugin-api";
import PostEventBuilder from "../components/modal/post-event-builder";
import {
  addReminder,
  onChangeDates,
  removeReminder,
  updateCustomField,
  updateEventRawInvitees,
  updateEventStatus,
  updateTimezone,
} from "../widgets/discourse-post-event";

function initializeEventBuilder(api) {
  const currentUser = api.getCurrentUser();
  const store = api.container.lookup("service:store");
  const modal = api.container.lookup("service:modal");

  api.addComposerToolbarPopupMenuOption({
    action: (toolbarEvent) => {
      const eventModel = store.createRecord("discourse-post-event-event");
      eventModel.setProperties({
        status: "public",
        custom_fields: {},
        starts_at: moment(),
        timezone: moment.tz.guess(),
      });

      modal.show(PostEventBuilder, {
        model: {
          event: eventModel,
          toolbarEvent,
          updateCustomField: (field, value) =>
            updateCustomField(eventModel, field, value),
          updateEventStatus: (status) => updateEventStatus(eventModel, status),
          updateEventRawInvitees: (rawInvitees) =>
            updateEventRawInvitees(eventModel, rawInvitees),
          removeReminder: (reminder) => removeReminder(eventModel, reminder),
          addReminder: () => addReminder(eventModel),
          onChangeDates: (changes) => onChangeDates(eventModel, changes),
          updateTimezone: (newTz, startsAt, endsAt) =>
            updateTimezone(eventModel, newTz, startsAt, endsAt),
        },
      });
    },
    group: "insertions",
    icon: "calendar-day",
    label: "discourse_calendar.discourse_post_event.builder_modal.attach",
    condition: (composer) => {
      if (!currentUser || !currentUser.can_create_discourse_post_event) {
        return false;
      }

      const composerModel = composer.model;
      return (
        composerModel &&
        !composerModel.replyingToTopic &&
        (composerModel.topicFirstPost ||
          composerModel.creatingPrivateMessage ||
          (composerModel.editingPost &&
            composerModel.post &&
            composerModel.post.post_number === 1))
      );
    },
  });
}

export default {
  name: "add-post-event-builder",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (siteSettings.discourse_post_event_enabled) {
      withPluginApi("0.8.7", initializeEventBuilder);
    }
  },
};
