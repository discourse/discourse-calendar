import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("add-to-calendar-button", {
  tagName: "button.add-to-calendar-button.btn.btn-default.btn-small",

  click(event) {
    event.preventDefault();
    this.sendWidgetAction("addToGoogleCalendar");
  },

  template: hbs`
    {{d-icon "google"}}
    <span class="label">
      {{i18n "discourse_post_event.event_ui.add_to_calendar"}}
    </span>
    {{d-icon "external-link-alt"}}
  `
});
