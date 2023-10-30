import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("discourse-post-event-status", {
  tagName: "div.event-status",

  buildKey: (attrs) => `discourse-post-event-status-${attrs.id}`,

  buildClasses(attrs) {
    if (attrs.watchingInvitee) {
      return `status-${attrs.watchingInvitee.status}`;
    }
  },

  template: hbs`
    {{#unless attrs.minimal}}
      {{attach widget="going-button"}}
    {{/unless}}
    {{attach widget="interested-button"}}
    {{#unless attrs.minimal}}
      {{attach widget="not-going-button"}}
    {{/unless}}
  `,
});
