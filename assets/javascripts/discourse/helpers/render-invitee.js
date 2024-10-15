import { htmlSafe } from "@ember/template";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { userPath } from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";
import { htmlHelper } from "discourse-common/lib/helpers";

export default htmlHelper((invitee) => {
  const user = invitee.user || invitee;
  const path = userPath(user.username);
  const template = `
    <a href="${path}" data-user-card="${user.username}">
      <span class="user">
        ${renderAvatar(user, { imageSize: "medium" })}
        <span class="username">
         ${formatUsername(user.username)}
        </span>
      </span>
    </a>
  `;

  return htmlSafe(template);
});
