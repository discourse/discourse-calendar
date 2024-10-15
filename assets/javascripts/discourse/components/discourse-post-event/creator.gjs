import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { formatUsername } from "discourse/lib/utilities";
import { avatarImg } from "discourse-common/lib/avatar-utils";

export default class DiscoursePostEventCreator extends Component {
  get username() {
    return this.args.user.name || formatUsername(this.args.user.username);
  }

  get avatarImage() {
    return htmlSafe(
      avatarImg({
        avatarTemplate: this.args.user.avatar_template,
        size: "tiny",
        title: this.args.user.name || this.args.user.username,
      })
    );
  }

  <template>
    <span class="event-creator">
      <a class="topic-invitee-avatar" data-user-card={{@user.username}}>
        {{this.avatarImage}}
        <span class="username">{{this.username}}</span>
      </a>
    </span>
  </template>
}
