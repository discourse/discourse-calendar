import { h } from "virtual-dom";
import { formatUsername } from "discourse/lib/utilities";
import { avatarImg } from "discourse/widgets/post";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("discourse-post-event-creator", {
  tagName: "span.event-creator",

  html(attrs) {
    const { name, username, avatar_template } = attrs.user;

    return h(
      "a",
      {
        attributes: {
          class: "topic-invitee-avatar",
          "data-user-card": username,
        },
      },
      [
        avatarImg("tiny", {
          template: avatar_template,
          username: name || formatUsername(username),
        }),
        h(
          "span",
          { attributes: { class: "username" } },
          name || formatUsername(username)
        ),
      ]
    );
  },
});
