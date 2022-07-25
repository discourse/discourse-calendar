import I18n from "I18n";
import TextLib from "discourse/lib/text";
import Group from "discourse/models/group";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import Controller from "@ember/controller";
import { action, computed, set } from "@ember/object";
import { equal, gte } from "@ember/object/computed";
import { extractError } from "discourse/lib/ajax-error";
import bootbox from "bootbox";
import { buildParams, replaceRaw } from "../../lib/raw-event-helper";

const DEFAULT_REMINDER = { value: 15, unit: "minutes", period: "before" };

function replaceTimezone(val, newTimezone) {
  return moment.tz(val.format("YYYY-MM-DDTHH:mm"), newTimezone);
}

export default Controller.extend(ModalFunctionality, {
  reminders: null,
  isLoadingReminders: false,

  init() {
    this._super(...arguments);

    this.set("reminderUnits", ["minutes", "hours", "days", "weeks"]);
    this.set("reminderPeriods", ["before", "after"]);
    this.set("availableRecurrences", [
      {
        id: "every_day",
        name: I18n.t("discourse_post_event.builder_modal.recurrence.every_day"),
      },
      {
        id: "every_month",
        name: I18n.t(
          "discourse_post_event.builder_modal.recurrence.every_month"
        ),
      },
      {
        id: "every_weekday",
        name: I18n.t(
          "discourse_post_event.builder_modal.recurrence.every_weekday"
        ),
      },
      {
        id: "every_week",
        name: I18n.t(
          "discourse_post_event.builder_modal.recurrence.every_week"
        ),
      },
      {
        id: "every_two_weeks",
        name: I18n.t(
          "discourse_post_event.builder_modal.recurrence.every_two_weeks"
        ),
      },
    ]);
  },

  modalTitle: computed("model.eventModel.isNew", {
    get() {
      return this.model.eventModel.isNew
        ? "create_event_title"
        : "update_event_title";
    },
  }),

  allowedCustomFields: computed(
    "siteSettings.discourse_post_event_allowed_custom_fields",
    function () {
      return this.siteSettings.discourse_post_event_allowed_custom_fields
        .split("|")
        .filter(Boolean);
    }
  ),

  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: true });
  },

  allowsInvitees: equal("model.eventModel.status", "private"),

  addReminderDisabled: gte("model.eventModel.reminders.length", 5),

  @action
  onChangeCustomField(field, event) {
    const value = event.target.value;
    set(this.model.eventModel.custom_fields, field, value);
  },

  @action
  onChangeStatus(newStatus) {
    this.model.eventModel.set("raw_invitees", []);

    if (newStatus === "private") {
      this.setRawInvitees(
        null,
        this.model.eventModel.raw_invitees.filter((x) => x !== "trust_level_0")
      );
    }
    this.set("model.eventModel.status", newStatus);
  },

  @action
  setRawInvitees(_, newInvitees) {
    this.set("model.eventModel.raw_invitees", newInvitees);
  },

  @action
  removeReminder(reminder) {
    this.model.eventModel.reminders.removeObject(reminder);
  },

  @action
  addReminder() {
    if (!this.model.eventModel.reminders) {
      this.model.eventModel.set("reminders", []);
    }

    this.model.eventModel.reminders.pushObject(
      Object.assign({}, DEFAULT_REMINDER)
    );
  },

  startsAt: computed("model.eventModel.starts_at", {
    get() {
      return moment(this.model.eventModel.starts_at).tz(
        this.model.eventModel.timezone || "UTC"
      );
    },
  }),

  endsAt: computed("model.eventModel.ends_at", {
    get() {
      return (
        this.model.eventModel.ends_at &&
        moment(this.model.eventModel.ends_at).tz(
          this.model.eventModel.timezone || "UTC"
        )
      );
    },
  }),

  standaloneEvent: equal("model.eventModel.status", "standalone"),
  publicEvent: equal("model.eventModel.status", "public"),
  privateEvent: equal("model.eventModel.status", "private"),

  @action
  onChangeDates(changes) {
    this.model.eventModel.setProperties({
      starts_at: changes.from,
      ends_at: changes.to,
    });
  },

  @action
  onChangeTimezone(newTz) {
    this.model.eventModel.setProperties({
      timezone: newTz,
      starts_at: replaceTimezone(this.startsAt, newTz),
      ends_at: this.endsAt && replaceTimezone(this.endsAt, newTz),
    });
  },

  @action
  destroyPostEvent() {
    bootbox.confirm(
      I18n.t("discourse_post_event.builder_modal.confirm_delete"),
      I18n.t("no_value"),
      I18n.t("yes_value"),
      (confirmed) => {
        if (confirmed) {
          return this.store
            .find("post", this.model.eventModel.id)
            .then((post) => {
              const raw = post.raw;
              const newRaw = this._removeRawEvent(raw);
              const props = {
                raw: newRaw,
                edit_reason: I18n.t("discourse_post_event.destroy_event"),
              };

              return TextLib.cookAsync(newRaw).then((cooked) => {
                props.cooked = cooked.string;
                return post
                  .save(props)
                  .catch((e) => this.flash(extractError(e), "error"))
                  .then((result) => result && this.send("closeModal"));
              });
            })
            .catch((e) => this.flash(extractError(e), "error"));
        }
      }
    );
  },

  @action
  createEvent() {
    if (!this.startsAt) {
      this.send("closeModal");
      return;
    }

    const eventParams = buildParams(
      this.startsAt,
      this.endsAt,
      this.model.eventModel,
      this.siteSettings
    );
    const markdownParams = [];
    Object.keys(eventParams).forEach((key) => {
      let value = eventParams[key];
      markdownParams.push(`${key}="${value}"`);
    });

    this.toolbarEvent.addText(`[event ${markdownParams.join(" ")}]\n[/event]`);
    this.send("closeModal");
  },

  @action
  updateEvent() {
    return this.store.find("post", this.model.eventModel.id).then((post) => {
      const raw = post.raw;
      const eventParams = buildParams(
        this.startsAt,
        this.endsAt,
        this.model.eventModel,
        this.siteSettings
      );

      const newRaw = replaceRaw(eventParams, raw);

      if (newRaw) {
        const props = {
          raw: newRaw,
          edit_reason: I18n.t("discourse_post_event.edit_reason"),
        };

        return TextLib.cookAsync(newRaw).then((cooked) => {
          props.cooked = cooked.string;
          return post
            .save(props)
            .catch((e) => this.flash(extractError(e), "error"))
            .then((result) => result && this.send("closeModal"));
        });
      }
    });
  },

  _removeRawEvent(raw) {
    const eventRegex = new RegExp(`\\[event\\s(.*?)\\]\\n\\[\\/event\\]`, "m");
    return raw.replace(eventRegex, "");
  },
});
