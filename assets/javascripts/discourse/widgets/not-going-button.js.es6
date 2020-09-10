import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("not-going-button", {
  tagName: "button.not-going-button.btn.btn-default",

  click() {
    this.sendWidgetAction("changeWatchingInviteeStatus", "not_going");
  },

  template: hbs`
    {{d-icon "times"}}
    <span class="label">
      {{i18n "discourse_post_event.models.invitee.status.not_going"}}
    </span>
  `,
});
