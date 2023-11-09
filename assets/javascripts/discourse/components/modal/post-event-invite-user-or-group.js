import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { tracked } from "@glimmer/tracking";

export default class PostEventInviteUserOrGroup extends Component {
  @tracked invitedNames = null;
  @tracked flash = null;

  @action
  async invite() {
    try {
      await ajax(
        `/discourse-post-event/events/${this.args.model.event.id}/invite.json`,
        {
          data: { invites: this.invitedNames || [] },
          type: "POST",
        }
      );
      this.args.closeModal();
    } catch (e) {
      this.flash = extractError(e);
    }
  }
}
