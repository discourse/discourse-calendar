import ModalFunctionality from "discourse/mixins/modal-functionality";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { debounce } from "@ember/runloop";

export default Controller.extend(ModalFunctionality, {
  invitees: null,
  filter: null,
  isLoading: false,
  type: "going",

  onShow() {
    this._fetchInvitees();
  },
  @action
  toggleViewingFilter(filter) {
    this.onFilterChanged(filter);
  },
  @action
  toggleType(type) {
    this.set("type", type);
    this._fetchInvitees(this.filter);
  },

  @action
  onFilterChanged(filter) {
    // TODO: Use discouseDebounce after the 2.7 release.
    let debounceFunc = debounce;

    try {
      debounceFunc = require("discourse-common/lib/debounce").default;
    } catch (_) {}

    debounceFunc(this, this._fetchInvitees, filter, this.type, 250);
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
        type: this.type,
      })
      .then((invitees) => this.set("invitees", invitees))
      .finally(() => this.set("isLoading", false));
  },
});
