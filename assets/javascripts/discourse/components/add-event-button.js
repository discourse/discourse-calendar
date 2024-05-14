import Component from '@ember/component';
import { action } from '@ember/object';
import EmberObject from "@ember/object";
import PostEventBuilder from "./modal/post-event-builder";
import {
  addReminder,
  onChangeDates,
  removeReminder,
  updateCustomField,
  updateEventRawInvitees,
  updateEventStatus,
  updateTimezone,
} from "../widgets/discourse-post-event";

export default class AddEventButton extends Component {
  @action
  showAddEventModal() {
    const store = this.api.container.lookup('service:store');
    const modal = this.api.container.lookup('service:modal');

    const eventModel = store.createRecord("discourse-post-event-event");

    eventModel.setProperties({
      status: "public",
      custom_fields: EmberObject.create({}),
      starts_at: moment(),
      timezone: moment.tz.guess(),
    });

    console.log("Access calendar_categories_id:", this.siteSettings.calendar_categories_id);

    modal.show(PostEventBuilder, {
      model: {
        event: eventModel,
        api: this.api,
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
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    const $container = $(".composer-fields .title-and-category");
    $container.addClass("show-event-controls");

    $(".composer-controls-event").appendTo($container);

    this.composerResized();
  }

  composerResized() {}
}
