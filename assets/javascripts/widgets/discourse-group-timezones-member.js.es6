import { h } from "virtual-dom";
import { avatarImg } from "discourse/widgets/post";
import { createWidget } from "discourse/widgets/widget";
import { formatUsername } from "discourse/lib/utilities";

export default createWidget("discourse-group-timezones-member", {
  tagName: "li.group-timezones-member",

  buildClasses(attrs) {
    return attrs.usersOnHoliday.includes(attrs.member.username)
      ? "on-holiday"
      : "not-on-holiday";
  },

  html(attrs) {
    const { name, username, avatar_template } = attrs.member;

    return h(
      "a",
      {
        attributes: {
          class: "group-timezones-member-avatar",
          "data-user-card": username
        }
      },
      avatarImg("small", {
        template: avatar_template,
        username: name || formatUsername(username)
      })
    );
  }
});
