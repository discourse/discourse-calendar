import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { userPath } from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";

export default class User extends Component {
  get avatar() {
    return htmlSafe(renderAvatar(this.args.user, { imageSize: "medium" }));
  }

  get userPath() {
    return userPath(this.args.user.username);
  }

  get username() {
    return formatUsername(this.args.user.username);
  }

  <template>
    <a href={{this.userPath}} data-user-card={{@user.username}}>
      <span class="user">
        {{this.avatar}}
        <span class="username">
          {{this.username}}
        </span>
      </span>
    </a>
  </template>
}
