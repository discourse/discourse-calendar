import { createWidget } from "discourse/widgets/widget";
import hbs from "discourse/widgets/hbs-compiler";

export default createWidget("discourse-post-event-status", {
  tagName: "div.event-status",

  buildKey: (attrs) => `discourse-post-event-status-${attrs.id}`,

  buildClasses(attrs) {
    if (attrs.watchingInvitee) {
      return `status-${attrs.watchingInvitee.status}`;
    }
  },

  template: hbs`
    {{attach widget="going-button"}}
    {{attach widget="interested-button"}}
    {{attach widget="not-going-button"}}
  `,
});
