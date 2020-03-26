import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("post-event-dates", {
  tagName: "section.post-event-dates",

  template: hbs`
    {{d-icon "clock"}}
    <span class="date">{{{attrs.localDates}}}</span>
  `
});
