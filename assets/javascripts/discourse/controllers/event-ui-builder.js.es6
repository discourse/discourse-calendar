import ModalFunctionality from "discourse/mixins/modal-functionality";
import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { equal } from "@ember/object/computed";
import { extractError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, {
  modalTitle: computed("model.postEvent.isNew", {
    get() {
      return this.model.postEvent.isNew
        ? "create_event_title"
        : "update_event_title";
    }
  }),

  allowsInvitees: equal("model.postEvent.status", "private"),

  @action
  setRawInvitees(_, newInvitees) {
    this.set("model.postEvent.raw_invitees", newInvitees);
  },

  startsAt: computed("model.postEvent.starts_at", {
    get() {
      return this.model.postEvent.starts_at;
    }
  }),

  endsAt: computed("model.postEvent.ends_at", {
    get() {
      return this.model.postEvent.ends_at;
    }
  }),

  standaloneEvent: equal("model.postEvent.status", "standalone"),
  publicEvent: equal("model.postEvent.status", "public"),
  privateEvent: equal("model.postEvent.status", "private"),

  inviteesOptions: computed("model.postEvent.status", function() {
    const options = [];

    if (!this.standaloneEvent) {
      options.push({
        label: I18n.t("event.display_invitees.everyone"),
        value: "everyone"
      });

      if (this.privateEvent) {
        options.push({
          label: I18n.t("event.display_invitees.invitees_only"),
          value: "invitees_only"
        });
      }

      options.push({
        label: I18n.t("event.display_invitees.none"),
        value: "none"
      });
    }

    return options;
  }),

  @action
  onChangeDates(changes) {
    this.model.postEvent.setProperties({
      starts_at: moment(changes.from)
        .utc()
        .toISOString(),
      ends_at: changes.to
        ? moment(changes.to)
            .utc()
            .toISOString()
        : null
    });
  },

  @action
  destroyPostEvent() {
    bootbox.confirm(
      I18n.t("event.ui_builder.confirm_delete"),
      I18n.t("no_value"),
      I18n.t("yes_value"),
      confirmed => {
        if (confirmed) {
          this.model.postEvent
            .destroyRecord()
            .then(() => this.send("closeModal"));
        }
      }
    );
  },

  @action
  createEvent() {
    this.model.postEvent
      .save()
      .then(() => this.send("closeModal"))
      .catch(e => this.flash(extractError(e), "error"));
  },

  @action
  updateEvent() {
    this.model.postEvent
      .save()
      .then(() => this.send("closeModal"))
      .catch(e => this.flash(extractError(e), "error"));
  }
});
