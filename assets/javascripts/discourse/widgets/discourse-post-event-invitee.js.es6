import { isPresent } from "@ember/utils";
import { h } from "virtual-dom";
import { avatarImg } from "discourse/widgets/post";
import { createWidget } from "discourse/widgets/widget";
import { formatUsername } from "discourse/lib/utilities";

export default createWidget("discourse-post-event-invitee", {
  tagName: "li.event-invitee",

  buildClasses(attrs) {
    const classes = [];

    if (isPresent(attrs.invitee.status)) {
      classes.push(`status-${attrs.invitee.status}`);
    }

    if (
      this.currentUser &&
      this.currentUser.username === attrs.invitee.user.username
    ) {
      classes.push("is-current-user");
    }

    return classes;
  },

  html(attrs) {
    const { name, username, avatar_template } = attrs.invitee.user;

    let statusIcon;
    switch (attrs.invitee.status) {
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

    const avatarContent = [
      avatarImg(this.site.mobileView ? "tiny" : "large", {
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
