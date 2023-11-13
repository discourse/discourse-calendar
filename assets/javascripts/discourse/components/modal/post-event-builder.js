import Component from "@glimmer/component";
import { action } from "@ember/object";
import { equal, gte } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { extractError } from "discourse/lib/ajax-error";
import { buildParams, replaceRaw } from "../../lib/raw-event-helper";
import { cook } from "discourse/lib/text";
import Group from "discourse/models/group";
import I18n from "I18n";
import { debounce } from "discourse-common/utils/decorators";

function replaceTimezone(val, newTimezone) {
  return moment.tz(val.format("YYYY-MM-DDTHH:mm"), newTimezone);
}

export default class PostEventBuilder extends Component {
  @service dialog;
  @service siteSettings;
  @service store;

  @tracked reminders = null;
  @tracked isLoadingReminders = false;
  @tracked flash = null;

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

  get allowedCustomFields() {
    return this.siteSettings.discourse_post_event_allowed_custom_fields
      .split("|")
      .filter(Boolean);
  }

  get addReminderDisabled() {
    return this.args.model.event.reminders.length >= 5;
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
  onChangeStatus(newStatus) {
    this.args.model.updateEventRawInvitees(this.args.model.event, []);
    // why are we doing this?
    if (newStatus === "private") {
      this.args.model.updateEventRawInvitees(
        this.args.model.event,
        this.args.model.event.raw_invitees.filter((x) => x !== "trust_level_0")
      );
    }
    this.args.model.updateEventStatus(this.args.model.event, newStatus);
  }

  @action
  setRawInvitees(_, newInvitees) {
    this.args.model.updateEventRawInvitees(this.args.model.event, newInvitees);
  }

  @debounce(250)
  setReminderValue(reminder, event) {
    console.log(reminder);
    this.args.model.updateReminderValue(reminder, event.target.value);
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

    this.toolbarEvent.addText(`[event ${markdownParams.join(" ")}]\n[/event]`);
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

  @debounce(250)
  setEventName(event) {
    this.args.model.updateEventName(this.args.model.event, event.target.value);
  }

  @debounce(250)
  setEventUrl(event) {
    this.args.model.updateEventUrl(this.args.model.event, event.target.value);
  }

  _removeRawEvent(raw) {
    const eventRegex = new RegExp(`\\[event\\s(.*?)\\]\\n\\[\\/event\\]`, "m");
    return raw.replace(eventRegex, "");
  }
}
