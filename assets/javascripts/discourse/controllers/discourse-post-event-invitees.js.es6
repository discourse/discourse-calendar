import ModalFunctionality from "discourse/mixins/modal-functionality";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import discourseDebounce from "discourse-common/lib/debounce";
import { debounce } from "@ember/runloop";

export default Controller.extend(ModalFunctionality, {
  invitees: null,
  filter: null,
  isLoading: false,

  onShow() {
    this._fetchInvitees();
  },

  @action
  onFilterChanged(filter) {
    // TODO: Use discouseDebounce after the 2.7 release.
    const debounceFunc = discourseDebounce || debounce;

    debounceFunc(this, this._fetchInvitees, filter, 250);
  },

  @action
  removeInvitee(invitee) {
    invitee.destroyRecord().then(() => this._fetchInvitees());
  },

  _fetchInvitees(filter) {
    this.set("isLoading", true);

    this.store
      .findAll("discourse-post-event-invitee", {
        filter,
        post_id: this.model.id,
      })
      .then((invitees) => this.set("invitees", invitees))
      .finally(() => this.set("isLoading", false));
  },
});
