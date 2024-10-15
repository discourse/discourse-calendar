import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { debounce } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default class PostEventInvitees extends Component {
  @service store;
  @service discoursePostEventApi;

  @tracked invitees;
  @tracked filter;
  @tracked isLoading = false;
  @tracked type = "going";

  constructor() {
    super(...arguments);
    this._fetchInvitees();
  }

  get title() {
    return I18n.t(
      `discourse_calendar.discourse_post_event.invitees_modal.${
        this.args.model.title || "title_invited"
      }`
    );
  }

  @action
  toggleType(type) {
    this.type = type;
    this._fetchInvitees(this.filter);
  }

  @debounce(250)
  onFilterChanged() {
    this._fetchInvitees(this.filter);
  }

  @action
  async removeInvitee(invitee) {
    await invitee.destroyRecord();
    this._fetchInvitees();
  }

  async _fetchInvitees(filter) {
    try {
      this.isLoading = true;

      this.invitees = await this.discoursePostEventApi.listEventInvitees(
        this.args.model.event,
        {
          filter,
          type: this.type,
        }
      );
    } finally {
      this.isLoading = false;
    }
  }
}
