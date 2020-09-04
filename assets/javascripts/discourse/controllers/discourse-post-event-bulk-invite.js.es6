import { isPresent } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import EmberObject, { action } from "@ember/object";
import { observes } from "discourse-common/utils/decorators";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import Controller from "@ember/controller";
import Group from "discourse/models/group";
import I18n from "I18n";

export default Controller.extend(ModalFunctionality, {
  bulkInvites: null,
  bulkInviteStatuses: null,
  bulkInviteDisabled: true,

  init() {
    this._super(...arguments);

    this.set("bulkInviteStatuses", [
      {
        label: I18n.t("discourse_post_event.models.invitee.status.unknown"),
        name: "unknown",
      },
      {
        label: I18n.t("discourse_post_event.models.invitee.status.going"),
        name: "going",
      },
      {
        label: I18n.t("discourse_post_event.models.invitee.status.not_going"),
        name: "not_going",
      },
      {
        label: I18n.t("discourse_post_event.models.invitee.status.interested"),
        name: "interested",
      },
    ]);
  },

  onShow() {
    this.set("bulkInvites", [
      EmberObject.create({ identifier: null, attendance: "unknown" }),
    ]);
  },

  @action
  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: true });
  },

  // TODO: improves core to avoid having to rely on observer for group changes
  // using onChangeCallback doesn't solve the issue as it doesn't provide the object
  @observes("bulkInvites.@each.identifier")
  setBulkInviteDisabled() {
    this.set(
      "bulkInviteDisabled",
      this.bulkInvites.filter((x) => isPresent(x.identifier)).length === 0
    );
  },

  @action
  sendBulkInvites() {
    return ajax(
      `/discourse-post-event/events/${this.model.eventModel.id}/bulk-invite.json`,
      {
        type: "POST",
        dataType: "json",
        contentType: "application/json",
        data: JSON.stringify({
          invitees: this.bulkInvites.filter((x) => isPresent(x.identifier)),
        }),
      }
    )
      .then((data) => {
        if (data.success) {
          this.send("closeModal");
        }
      })
      .catch((e) => this.flash(extractError(e), "error"));
  },

  @action
  removeBulkInvite(bulkInvite) {
    this.bulkInvites.removeObject(bulkInvite);

    if (!this.bulkInvites.length) {
      this.set("bulkInvites", [
        EmberObject.create({ identifier: null, attendance: "unknown" }),
      ]);
    }
  },

  @action
  addBulkInvite() {
    const attendance =
      this.bulkInvites.get("lastObject.attendance") || "unknown";
    this.bulkInvites.pushObject({ identifier: null, attendance });
  },

  @action
  uploadDone() {
    bootbox.alert(
      I18n.t("discourse_post_event.bulk_invite_modal.success"),
      () => {
        this.send("closeModal");
      }
    );
  },
});
