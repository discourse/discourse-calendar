import TextLib from "discourse/lib/text";
import Group from "discourse/models/group";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import Controller from "@ember/controller";
import { set, action, computed } from "@ember/object";
import { equal, gte } from "@ember/object/computed";
import { extractError } from "discourse/lib/ajax-error";
import { Promise } from "rsvp";

import { buildParams, replaceRaw } from "../../lib/raw-event-helper";

const DEFAULT_REMINDER = { value: 15, unit: "minutes", type: "notification" };

export default Controller.extend(ModalFunctionality, {
  reminders: null,
  isLoadingReminders: false,

  init() {
    this._super(...arguments);

    this.set("reminderUnits", ["minutes", "hours", "days", "weeks"]);
  },

  modalTitle: computed("model.eventModel.isNew", {
    get() {
      return this.model.eventModel.isNew
        ? "create_event_title"
        : "update_event_title";
    }
  }),

  allowedCustomFields: computed(
    "siteSettings.discourse_post_event_allowed_custom_fields",
    function() {
      return this.siteSettings.discourse_post_event_allowed_custom_fields
        .split("|")
        .filter(Boolean);
    }
  ),

  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: true });
  },

  allowsInvitees: equal("model.eventModel.status", "private"),

  addReminderDisabled: gte("reminders.length", 5),

  @action
  onChangeCustomField(field, event) {
    const value = event.target.value;
    set(this.model.eventModel.custom_fields, field, value);
  },

  @action
  setRawInvitees(_, newInvitees) {
    this.set("model.eventModel.raw_invitees", newInvitees);
  },

  @action
  removeReminder(reminder) {
    this.model.eventModel.reminders.removeObject(reminder);

    if (reminder.id) {
      this.set("isLoadingReminders", true);

      this.store
        .createRecord("discourse-post-event-reminder", {
          id: reminder.id,
          post_id: this.model.eventModel.id
        })
        .destroyRecord()
        .finally(() => this.set("isLoadingReminders", false));
    }
  },

  @action
  addReminder() {
    this.model.eventModel.reminders.pushObject(
      Object.assign({}, DEFAULT_REMINDER)
    );
  },

  startsAt: computed("model.eventModel.starts_at", {
    get() {
      return this.model.eventModel.starts_at
        ? moment(this.model.eventModel.starts_at)
        : moment();
    }
  }),

  endsAt: computed("model.eventModel.ends_at", {
    get() {
      return (
        this.model.eventModel.ends_at && moment(this.model.eventModel.ends_at)
      );
    }
  }),

  standaloneEvent: equal("model.eventModel.status", "standalone"),
  publicEvent: equal("model.eventModel.status", "public"),
  privateEvent: equal("model.eventModel.status", "private"),

  @action
  onChangeDates(changes) {
    this.model.eventModel.setProperties({
      starts_at: changes.from,
      ends_at: changes.to
    });
  },

  @action
  destroyPostEvent() {
    bootbox.confirm(
      I18n.t("discourse_post_event.builder_modal.confirm_delete"),
      I18n.t("no_value"),
      I18n.t("yes_value"),
      confirmed => {
        if (confirmed) {
          return this.store
            .find("post", this.model.eventModel.id)
            .then(post => {
              const raw = post.raw;
              const newRaw = this._removeRawEvent(raw);
              const props = {
                raw: newRaw,
                edit_reason: I18n.t("discourse_post_event.destroy_event")
              };

              return TextLib.cookAsync(newRaw).then(cooked => {
                props.cooked = cooked.string;
                return post
                  .save(props)
                  .catch(e => this.flash(extractError(e), "error"))
                  .then(result => result && this.send("closeModal"));
              });
            })
            .catch(e => this.flash(extractError(e), "error"));
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
      this.model.eventModel
    );
    const markdownParams = [];
    Object.keys(eventParams).forEach(key => {
      let value = eventParams[key];
      markdownParams.push(`${key}="${value}"`);
    });

    this.toolbarEvent.addText(`[event ${markdownParams.join(" ")}]\n[/event]`);
    this.send("closeModal");
  },

  @action
  updateEvent() {
    return this.store.find("post", this.model.eventModel.id).then(post => {
      const promises = [];

      // custom_fields are not stored on the raw and are updated separately
      const data = this.model.eventModel.getProperties(
        "custom_fields",
        "reminders"
      );
      promises.push(this.model.eventModel.update(data));

      const updateRawPromise = new Promise(resolve => {
        const raw = post.raw;
        const eventParams = buildParams(
          this.startsAt,
          this.endsAt,
          this.model.eventModel
        );
        const newRaw = replaceRaw(eventParams, raw);

        if (newRaw) {
          const props = {
            raw: newRaw,
            edit_reason: I18n.t("discourse_post_event.edit_reason")
          };

          return TextLib.cookAsync(newRaw).then(cooked => {
            props.cooked = cooked.string;
            return post
              .save(props)
              .catch(e => this.flash(extractError(e), "error"))
              .then(result => result && this.send("closeModal"))
              .finally(resolve);
          });
        } else {
          resolve();
        }
      });

      return Promise.all(promises.concat(updateRawPromise));
    });
  },

  _removeRawEvent(raw) {
    const eventRegex = new RegExp(`\\[event\\s(.*?)\\]\\n\\[\\/event\\]`, "m");
    return raw.replace(eventRegex, "");
  }
});
