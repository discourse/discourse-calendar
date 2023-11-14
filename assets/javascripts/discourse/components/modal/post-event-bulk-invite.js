import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import EmberObject, { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { isPresent } from "@ember/utils";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import Group from "discourse/models/group";
import I18n from "discourse-i18n";

export default class PostEventBulkInvite extends Component {
  @service dialog;

  @tracked
  bulkInvites = new TrackedArray([
    EmberObject.create({ identifier: null, attendance: "unknown" }),
  ]);
  @tracked bulkInviteDisabled = true;
  @tracked flash = null;

  get bulkInviteStatuses() {
    return [
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
    ];
  }

  @action
  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: true });
  }

  @action
  setBulkInviteDisabled() {
    this.bulkInviteDisabled =
      this.bulkInvites.filter((x) => isPresent(x.identifier)).length === 0;
  }

  @action
  async sendBulkInvites() {
    try {
      const response = await ajax(
        `/discourse-post-event/events/${this.args.model.event.id}/bulk-invite.json`,
        {
          type: "POST",
          dataType: "json",
          contentType: "application/json",
          data: JSON.stringify({
            invitees: this.bulkInvites.filter((x) => isPresent(x.identifier)),
          }),
        }
      );

      if (response.success) {
        this.args.closeModal();
      }
    } catch (e) {
      this.flash = extractError(e);
    }
  }

  @action
  removeBulkInvite(bulkInvite) {
    this.bulkInvites.removeObject(bulkInvite);

    if (!this.bulkInvites.length) {
      this.bulkInvites.pushObject(
        EmberObject.create({ identifier: null, attendance: "unknown" })
      );
    }
  }

  @action
  addBulkInvite() {
    const attendance =
      this.bulkInvites[this.bulkInvites.length - 1]?.attendance || "unknown";
    this.bulkInvites.pushObject(
      EmberObject.create({ identifier: null, attendance })
    );
  }

  @action
  async uploadDone() {
    await this.dialog.alert(
      I18n.t("discourse_post_event.bulk_invite_modal.success")
    );
    this.args.closeModal();
  }

  @action
  updateInviteIdentifier(bulkInvite, selected) {
    bulkInvite.identifier = selected[0];
    this.setBulkInviteDisabled();
  }
  @action
  updateBulkGroupInviteIdentifier(bulkInvite, _, groupNames) {
    bulkInvite.identifier = groupNames[0];
    this.setBulkInviteDisabled();
  }
}
