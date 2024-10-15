import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import AvatarFlair from "discourse/components/avatar-flair";
import concatClass from "discourse/helpers/concat-class";
import { formatUsername } from "discourse/lib/utilities";
import { avatarImg } from "discourse-common/lib/avatar-utils";

export default class DiscoursePostEventInvitee extends Component {
  @service site;
  @service currentUser;

  get statusIcon() {
    let statusIcon;
    switch (this.args.invitee.status) {
      case "going":
        statusIcon = "fa-check";
        break;
      case "interested":
        statusIcon = "fa-star";
        break;
      case "not_going":
        statusIcon = "fa-times";
        break;
    }
    return statusIcon;
  }

  get avatarImage() {
    return htmlSafe(
      avatarImg({
        avatarTemplate: this.args.invitee.user.avatar_template,
        size: this.site.mobileView ? "tiny" : "large",
        title: this.args.invitee.user.name
          ? formatUsername(this.args.invitee.user.name)
          : this.args.invitee.user.username,
      })
    );
  }

  <template>
    <li
      class={{concatClass
        "event-invitee"
        (if @invitee.status (concat "status-" @invitee.status))
        (if (eq this.currentUser.id @invitee.user.id) "is-current-user")
      }}
    >
      <a
        class="topic-invitee-avatar"
        data-user-card={{this.args.invitee.user.username}}
      >
        {{this.avatarImage}}
        {{#if this.statusIcon}}
          <AvatarFlair
            @flairName={{concat
              "discourse_calendar.discourse_post_event.models.invitee.status."
              this.args.invitee.status
            }}
            @flairUrl={{this.statusIcon}}
          />
        {{/if}}
      </a>
    </li>
  </template>
}
