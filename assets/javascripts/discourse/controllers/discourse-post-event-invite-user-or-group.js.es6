import ModalFunctionality from "discourse/mixins/modal-functionality";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { extractError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";

export default Controller.extend(ModalFunctionality, {
  invitedNames: null,

  @action
  setInvitedNames(_, invitedNames) {
    this.set("invitedNames", invitedNames);
  },

  onClose() {
    this.set("invitedNames", null);
  },

  @action
  invite() {
    return ajax(`/discourse-post-event/events/${this.model.id}/invite.json`, {
      data: { invites: this.invitedNames || [] },
      type: "POST",
    })
      .then(() => this.send("closeModal"))
      .catch((e) => this.flash(extractError(e), "error"));
  },
});
