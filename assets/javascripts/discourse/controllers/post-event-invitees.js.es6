import ModalFunctionality from "discourse/mixins/modal-functionality";
import Controller from "@ember/controller";
import { debounce } from "@ember/runloop";
import { action } from "@ember/object";

export default Controller.extend(ModalFunctionality, {
  invitees: null,
  filter: null,
  isLoading: false,

  onShow() {
    this._fetchInvitees();
  },

  @action
  onFilterChanged(filter) {
    debounce(this, this._fetchInvitees, filter, 250);
  },

  _fetchInvitees(filter) {
    this.set("isLoading", true);

    this.store
      .findAll("invitee", { "post-event-id": this.model.id, filter })
      .then(invitees => this.set("invitees", invitees))
      .finally(() => this.set("isLoading", false));
  }
});
