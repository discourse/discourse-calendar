import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import AvatarFlair from "discourse/components/avatar-flair";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";

export default class DiscoursePostEventInvitee extends Component {
  @service site;
  @service currentUser;

  get statusIcon() {
    switch (this.args.invitee.status) {
      case "going":
        return "fa-check";
      case "interested":
        return "fa-star";
      case "not_going":
        return "fa-times";
    }
  }

  <template>
    <li
      class={{concatClass
        "event-invitee"
        (if @invitee.status (concat "status-" @invitee.status))
        (if (eq this.currentUser.id @invitee.user.id) "is-current-user")
      }}
    >
      <a class="topic-invitee-avatar" data-user-card={{@invitee.user.username}}>
        {{avatar
          @invitee.user
          imageSize=(if this.site.mobileView "tiny" "large")
        }}
        {{#if this.statusIcon}}
          <AvatarFlair
            @flairName={{concat
              "discourse_calendar.discourse_post_event.models.invitee.status."
              @invitee.status
            }}
            @flairUrl={{this.statusIcon}}
          />
        {{/if}}
      </a>
    </li>
  </template>
}
