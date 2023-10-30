import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  invitedNames: null,

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
