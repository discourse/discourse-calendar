import { isPresent } from "@ember/utils";
import { h } from "virtual-dom";
import { avatarImg } from "discourse/widgets/post";
import { createWidget } from "discourse/widgets/widget";
import { formatUsername } from "discourse/lib/utilities";

export default createWidget("discourse-post-event-invitee", {
  tagName: "li.event-invitee",

  buildClasses(attrs) {
    if (isPresent(attrs.invitee.status)) {
      return `status-${attrs.invitee.status}`;
    }
  },

  html(attrs) {
    const { name, username, avatar_template } = attrs.invitee.user;

    let statusIcon;
    switch (attrs.invitee.status) {
      case "going":
        statusIcon = "fa-check";
        break;
      case "interested":
        statusIcon = "fa-question";
        break;
      case "not_going":
        statusIcon = "fa-times";
        break;
    }

    const avatarContent = [
      avatarImg("large", {
        template: avatar_template,
        username: name || formatUsername(username)
      })
    ];

    if (statusIcon) {
      avatarContent.push(
        this.attach("avatar-flair", {
          primary_group_name: `status-${attrs.invitee.status}`,
          primary_group_flair_url: statusIcon
        })
      );
    }
    return h(
      "a",
      {
        attributes: {
          class: "topic-invitee-avatar",
          "data-user-card": username
        }
      },
      avatarContent
    );
  }
});
