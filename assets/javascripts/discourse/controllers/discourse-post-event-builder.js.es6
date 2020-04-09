import ModalFunctionality from "discourse/mixins/modal-functionality";
import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { equal } from "@ember/object/computed";
import { extractError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, {
  modalTitle: computed("model.eventModel.isNew", {
    get() {
      return this.model.eventModel.isNew
        ? "create_event_title"
        : "update_event_title";
    }
  }),

  allowsInvitees: equal("model.eventModel.status", "private"),

  @action
  setRawInvitees(_, newInvitees) {
    this.set("model.eventModel.raw_invitees", newInvitees);
  },

  startsAt: computed("model.eventModel.starts_at", {
    get() {
      return this.model.eventModel.starts_at;
    }
  }),

  endsAt: computed("model.eventModel.ends_at", {
    get() {
      return this.model.eventModel.ends_at;
    }
  }),

  standaloneEvent: equal("model.eventModel.status", "standalone"),
  publicEvent: equal("model.eventModel.status", "public"),
  privateEvent: equal("model.eventModel.status", "private"),

  @action
  onChangeDates(changes) {
    this.model.eventModel.setProperties({
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
          this.model.eventModel
            .destroyRecord()
            .then(() => this.send("closeModal"));
        }
      }
    );
  },

  @action
  createEvent() {
    this.model.eventModel
      .save()
      .then(() => this.send("closeModal"))
      .catch(e => this.flash(extractError(e), "error"));
  },

  @action
  updateEvent() {
    this.model.eventModel
      .save()
      .then(() => this.send("closeModal"))
      .catch(e => this.flash(extractError(e), "error"));
  }
});
