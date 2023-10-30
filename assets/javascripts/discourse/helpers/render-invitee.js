import { htmlSafe } from "@ember/template";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { userPath } from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";
import { htmlHelper } from "discourse-common/lib/helpers";

export default htmlHelper((invitee) => {
  const path = userPath(invitee.user.username);
  const template = `
    <a href="${path}" data-user-card="${invitee.user.username}">
      <span class="user">
        ${renderAvatar(invitee.user, { imageSize: "medium" })}
        <span class="username">
         ${formatUsername(invitee.user.username)}
        </span>
      </span>
    </a>
  `;

  return htmlSafe(template);
});
