import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("post-event-invitees", {
  tagName: "section.post-event-invitees",

  transform(attrs) {
    return {
      isPrivateEvent: attrs.postEvent.status === "private",
      showAll:
        attrs.postEvent.should_display_invitees &&
        attrs.postEvent.stats.invited > 10
    };
  },

  template: hbs`
    <div class="header">
      <div class="post-event-invitees-status">
        <span>{{attrs.postEvent.stats.going}} Going -</span>
        <span>{{attrs.postEvent.stats.interested}} Interested -</span>
        <span>{{attrs.postEvent.stats.not_going}} Not going</span>
        {{#if transformed.isPrivateEvent}}
          <span class="invited">- on {{attrs.postEvent.stats.invited}} users invited</span>
        {{/if}}
      </div>

      {{#if transformed.showAll}}
        {{attach
          widget="button"
          attrs=(hash
            className="show-all btn-small"
            label="event.post_ui.show_all"
            action="showAllInvitees"
            actionParam=(hash postId=attrs.postEvent.id)
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
