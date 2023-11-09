import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { debounce } from "discourse-common/utils/decorators";
import { dasherize } from "@ember/string";

export default class DiscoursePostEventInvitees extends Component {
  @service store;

  @tracked invitees;
  @tracked filter;
  @tracked isLoading = false;
  @tracked type = "going";

  constructor() {
    super(...arguments);
    this._fetchInvitees();
  }

  get title() {
    return `discourse_post_event.invitees_modal.${
      this.args.model.params?.title || "title_invited"
    }`;
  }

  @action
  toggleViewingFilter(filter) {
    this.onFilterChanged(filter);
  }

  @action
  toggleType(type) {
    this.type = type;
    this._fetchInvitees(this.filter);
  }

  @debounce(250)
  onFilterChanged(filter) {
    this._fetchInvitees(filter);
  }

  @action
  async removeInvitee(invitee) {
    await invitee.destroyRecord();
    this._fetchInvitees();
  }

  async _fetchInvitees(filter) {
    try {
      this.isLoading = true;
      const invitees = await this.store.findAll(
        "discourse-post-event-invitee",
        {
          filter,
          post_id: this.args.model.event.id,
          type: this.type,
        }
      );

      this.invitees = invitees;
    } finally {
      this.isLoading = false;
    }
  }
}
