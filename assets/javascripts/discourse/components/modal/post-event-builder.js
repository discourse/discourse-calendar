import Component from "@glimmer/component";
import { action } from "@ember/object";
import { equal, gte } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class PostEventBuilder extends Component {
  @service dialog;
  @service siteSettings;
  @service store;

  @tracked reminders = null;
  @tracked isLoadingReminders = false;

  get reminderTypes() {
    return [
      { value: "notification", name: "Notification" },
      { value: "bumpTopic", name: "Bump Topic" },
    ];
  }

  get reminderUnits() {
    return [
      { value: "minutes", name: "Minutes" },
      { value: "hours", name: "Hours" },
      { value: "days", name: "Days" },
      { value: "weeks", name: "Weeks" },
    ];
  }

  get reminderPeriods() {
    return [
      { value: "before", name: "Before" },
      { value: "after", name: "After" },
    ];
  }

  get availableRecurrences() {
    return [
      { id: "every_day", name: "Every Day" },
      { id: "every_month", name: "Every Month" },
      { id: "every_weekday", name: "Every Weekday" },
      { id: "every_week", name: "Every Week" },
      { id: "every_two_weeks", name: "Every Two Weeks" },
      { id: "every_four_weeks", name: "Every Four Weeks" },
    ];
  }

  get allowedCustomFields() {
    return this.siteSettings.discourse_post_event_allowed_custom_fields
      .split("|")
      .filter(Boolean);
  }

  get addReminderDisabled() {
    return this.args.model.event.reminders.length >= 5;
  }

  @action
  onChangeCustomField(field, event) {
    this.args.model.event.custom_fields[field] = event.target.value;
  }

  @action
  onChangeStatus(newStatus) {
    this.args.model.event.set("raw_invitees", []);

    if (newStatus === "private") {
      this.setRawInvitees(
        null,
        this.args.model.event.raw_invitees.filter((x) => x !== "trust_level_0")
      );
    }
    this.set("model.eventModel.status", newStatus);
  }

  @action
  setRawInvitees(_, newInvitees) {
    this.set("model.eventModel.raw_invitees", newInvitees);
  }

  @action
  removeReminder(reminder) {
    this.args.model.event.reminders.removeObject(reminder);
  }

  @action
  addReminder() {
    if (!this.args.model.event.reminders) {
      this.args.model.event.set("reminders", []);
    }

    this.args.model.event.reminders.pushObject({ ...DEFAULT_REMINDER });
  }

  get startsAt() {
    return moment(this.args.model.event.starts_at).tz(
      this.args.model.event.timezone || "UTC"
    );
  }

  get endsAt() {
    return (
      this.args.model.event.ends_at &&
      moment(this.args.model.event.ends_at).tz(
        this.args.model.event.timezone || "UTC"
      )
    );
  }

  @action
  onChangeDates(changes) {
    this.args.model.event.setProperties({
      starts_at: changes.from,
      ends_at: changes.to,
    });
  }

  @action
  onChangeTimezone(newTz) {
    this.args.model.event.setProperties({
      timezone: newTz,
      starts_at: replaceTimezone(this.startsAt, newTz),
      ends_at: this.endsAt && replaceTimezone(this.endsAt, newTz),
    });
  }

  @action
  destroyPostEvent() {
    this.dialog.yesNoConfirm({
      message: "Confirm delete",
      didConfirm: () => {
        return this.store
          .find("post", this.args.model.event.id)
          .then((post) => {
            const raw = post.raw;
            const newRaw = this._removeRawEvent(raw);
            const props = {
              raw: newRaw,
              edit_reason: "Destroy event",
            };

            return cook(newRaw).then((cooked) => {
              props.cooked = cooked.string;
              return post
                .save(props)
                .catch((e) => this.flash(extractError(e), "error"))
                .then((result) => result && this.send("closeModal"));
            });
          })
          .catch((e) => this.flash(extractError(e), "error"));
      },
    });
  }

  @action
  createEvent() {
    if (!this.startsAt) {
      this.args.closeModal();
      return;
    }

    const eventParams = buildParams(
      this.startsAt,
      this.endsAt,
      this.args.model.event,
      this.siteSettings
    );
    const markdownParams = [];
    Object.keys(eventParams).forEach((key) => {
      let value = eventParams[key];
      markdownParams.push(`${key}="${value}"`);
    });

    this.toolbarEvent.addText(`[event ${markdownParams.join(" ")}]\n[/event]`);
    this.args.closeModal();
  }

  @action
  updateEvent() {
    return this.store.find("post", this.args.model.event.id).then((post) => {
      const raw = post.raw;
      const eventParams = buildParams(
        this.startsAt,
        this.endsAt,
        this.args.model.event,
        this.siteSettings
      );

      const newRaw = replaceRaw(eventParams, raw);

      if (newRaw) {
        const props = {
          raw: newRaw,
          edit_reason: "Edit reason",
        };

        return cook(newRaw).then((cooked) => {
          props.cooked = cooked.string;
          return post
            .save(props)
            .catch((e) => this.flash(extractError(e), "error"))
            .then((result) => result && this.send("closeModal"));
        });
      }
    });
  }

  _removeRawEvent(raw) {
    const eventRegex = new RegExp(`\\[event\\s(.*?)\\]\\n\\[\\/event\\]`, "m");
    return raw.replace(eventRegex, "");
  }
}
