import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("going-button", {
  tagName: "button.going-button.btn.btn-default",

  click() {
    this.sendWidgetAction("changeWatchingInviteeStatus", "going");
  },

  template: hbs`
    {{d-icon "check"}}
    <span class="label">
      {{i18n "discourse_post_event.models.invitee.status.going"}}
    </span>
  `
});
