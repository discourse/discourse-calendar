import { h } from "virtual-dom";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("post-event-status", {
  tagName: "select.post-event-status",

  change(event) {
    this.sendWidgetAction("changeWatchingInviteeStatus", event.target.value);
  },

  buildClasses(attrs) {
    if (attrs.watchingInvitee) {
      return `status-${attrs.watchingInvitee.status}`;
    }
  },

  html(attrs) {
    const statuses = [
      { value: null, name: I18n.t("event.invitee_status.unknown") },
      { value: "going", name: I18n.t("event.invitee_status.going") },
      { value: "interested", name: I18n.t("event.invitee_status.interested") },
      { value: "not_going", name: I18n.t("event.invitee_status.not_going") }
    ];

    const value = attrs.watchingInvitee ? attrs.watchingInvitee.status : null;

    return statuses.map(status =>
      h(
        "option",
        {
          value: status.value,
          class: `status-${status.value}`,
          selected: status.value === value
        },
        status.name
      )
    );
  }
});
