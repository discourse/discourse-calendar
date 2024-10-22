import Component from "@glimmer/component";
import avatar from "discourse/helpers/avatar";
import { formatUsername } from "discourse/lib/utilities";

export default class DiscoursePostEventCreator extends Component {
  get username() {
    return this.args.user.name || formatUsername(this.args.user.username);
  }

  <template>
    <span class="event-creator">
      <a class="topic-invitee-avatar" data-user-card={{@user.username}}>
        {{avatar @user imageSize="tiny"}}
        <span class="username">{{this.username}}</span>
      </a>
    </span>
  </template>
}
