import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("post-event-invitees", {
  tagName: "section.post-event-invitees",

  transform(attrs) {
    return {
      showAll: attrs.postEvent.stats && attrs.postEvent.stats.invited > 10
    };
  },

  template: hbs`
    <div class="header">
      <div class="post-event-invitees-status">
        <span>{{attrs.postEvent.stats.going}} Going -</span>
        <span>{{attrs.postEvent.stats.interested}} Interested -</span>
        <span>{{attrs.postEvent.stats.not_going}} Not going -</span>
        <span class="invited">on {{attrs.postEvent.stats.invited}} users invited</span>
      </div>

      {{#if transformed.showAll}}
        {{attach
          widget="button"
          attrs=(hash
            className="show-all btn-small"
            label="event.post_ui.show_all"
            action="showAllInvitees"
            actionParam=attrs.postEvent.id
          )
        }}
      {{/if}}
    </div>
    <ul class="post-event-invitees-avatars">
      {{#each attrs.postEvent.sample_invitees as |invitee|}}
        {{attach
          widget="post-event-invitee"
          attrs=(hash invitee=invitee)
        }}
      {{/each}}
    </ul>
  `
});
