import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { extractError } from "discourse/lib/ajax-error";
import { cook } from "discourse/lib/text";
import Group from "discourse/models/group";
import { buildParams, replaceRaw } from "../../lib/raw-event-helper";

export default class PostEventBuilder extends Component {
  @service dialog;
  @service siteSettings;
  @service store;

  @tracked flash = null;
  @tracked startsAt = moment(this.args.model.event.starts_at).tz(
    this.args.model.event.timezone || "UTC"
  );
  @tracked
  endsAt =
    this.args.model.event.ends_at &&
    moment(this.args.model.event.ends_at).tz(
      this.args.model.event.timezone || "UTC"
    );

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
    return this.args.model.event.reminders?.length >= 5;
  }

  @action
  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: true });
  }

  @action
  setCustomField(field, target) {
    this.args.model.updateCustomField(field, target.value);
  }

  @action
  onChangeDates(dates) {
    this.args.model.onChangeDates(dates);
    this.startsAt = dates.from;
    this.endsAt = dates.to;
  }

  @action
  onChangeStatus(newStatus) {
    this.args.model.updateEventRawInvitees([]);
    this.args.model.updateEventStatus(newStatus);
  }

  @action
  setRawInvitees(_, newInvitees) {
    this.args.model.updateEventRawInvitees(newInvitees);
  }

  @action
  setNewTimezone(newTz) {
    this.args.model.updateTimezone(newTz, this.startsAt, this.endsAt);
    this.startsAt = moment(this.args.model.event.starts_at).tz(newTz);
    this.endsAt = moment(this.args.model.event.ends_at).tz(
      this.args.model.event.timezone
    );
  }

  @action
  async destroyPostEvent() {
    try {
      const confirmResult = await this.dialog.yesNoConfirm({
        message: "Confirm delete",
      });

      if (confirmResult) {
        const post = await this.store.find("post", this.args.model.event.id);
        const raw = post.raw;
        const newRaw = this._removeRawEvent(raw);
        const props = {
          raw: newRaw,
          edit_reason: "Destroy event",
        };

        const cooked = await cook(newRaw);
        props.cooked = cooked.string;

        const result = await post.save(props);
        if (result) {
          this.args.closeModal();
        }
      }
    } catch (e) {
      this.flash = extractError(e);
    }
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

    this.args.model.toolbarEvent.addText(
      `[event ${markdownParams.join(" ")}]\n[/event]`
    );
    this.args.closeModal();
  }

  @action
  async updateEvent() {
    try {
      const post = await this.store.find("post", this.args.model.event.id);
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

        const cooked = await cook(newRaw);
        props.cooked = cooked.string;

        const result = await post.save(props);
        if (result) {
          this.args.closeModal();
        }
      }
    } catch (e) {
      this.flash = extractError(e);
    }
  }

  _removeRawEvent(raw) {
    const eventRegex = new RegExp(`\\[event\\s(.*?)\\]\\n\\[\\/event\\]`, "m");
    return raw.replace(eventRegex, "");
  }
}
