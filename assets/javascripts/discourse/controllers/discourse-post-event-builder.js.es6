import TextLib from "discourse/lib/text";
import Group from "discourse/models/group";
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

  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: true });
  },

  allowsInvitees: equal("model.eventModel.status", "private"),

  @action
  setRawInvitees(_, newInvitees) {
    this.set("model.eventModel.raw_invitees", newInvitees);
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

              if (newRaw) {
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
              }
            });
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

    const eventParams = this._buildEventParams();
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
    const eventParams = this._buildEventParams();
    return this.store.find("post", this.model.eventModel.id).then(post => {
      const raw = post.raw;
      const newRaw = this._replaceRawEvent(eventParams, raw);

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
            .then(result => result && this.send("closeModal"));
        });
      }
    });
  },

  _buildEventParams() {
    const eventParams = {};

    if (this.startsAt) {
      eventParams.start = moment(this.startsAt)
        .utc()
        .format("YYYY-MM-DD HH:mm");
    } else {
      eventParams.start = moment()
        .utc()
        .format("YYYY-MM-DD HH:mm");
    }

    if (this.model.eventModel.status) {
      eventParams.status = this.model.eventModel.status;
    }

    if (this.model.eventModel.name) {
      eventParams.name = this.model.eventModel.name;
    }

    if (this.endsAt) {
      eventParams.end = moment(this.endsAt)
        .utc()
        .format("YYYY-MM-DD HH:mm");
    }

    if (this.model.eventModel.status === "private") {
      eventParams.allowedGroups = (
        this.model.eventModel.raw_invitees || []
      ).join(",");
    }

    return eventParams;
  },

  _removeRawEvent(raw) {
    const eventRegex = new RegExp(`\\[event\\s(.*?)\\]\\n\\[\\/event\\]`, "m");
    return raw.replace(eventRegex, "");
  },

  _replaceRawEvent(eventparams, raw) {
    const eventRegex = new RegExp(`\\[event\\s(.*?)\\]`, "m");
    const eventMatches = raw.match(eventRegex);

    if (eventMatches && eventMatches[1]) {
      const markdownParams = [];
      const eventParams = this._buildEventParams();
      Object.keys(eventParams).forEach(eventParam => {
        const value = eventParams[eventParam];
        if (value && value.length) {
          markdownParams.push(`${eventParam}="${eventParams[eventParam]}"`);
        }
      });

      return raw.replace(eventRegex, `[event ${markdownParams.join(" ")}]`);
    }

    return false;
  }
});
