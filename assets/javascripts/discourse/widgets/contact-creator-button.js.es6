import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("contact-creator-button", {
  tagName: "button.contact-creator-button.btn.btn-default.btn-small",

  click(event) {
    event.preventDefault();
    this.sendWidgetAction("sendPMToCreator");
  },

  template: hbs`
    {{d-icon "envelope"}}
    <span class="label">
      {{i18n "discourse_post_event.event_ui.send_pm_to_creator" username=this.attrs.username}}
    </span>
  `
});
