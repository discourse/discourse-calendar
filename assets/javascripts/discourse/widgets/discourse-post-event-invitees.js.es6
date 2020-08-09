import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("discourse-post-event-invitees", {
  tagName: "section.event-invitees",

  transform(attrs) {
    return {
      isPrivateEvent: attrs.eventModel.status === "private"
    };
  },

  template: hbs`
    <div class="header">
      <div class="event-invitees-status">
        <span>{{attrs.eventModel.stats.going}} {{i18n "discourse_post_event.models.invitee.status.going"}} -</span>
        <span>{{attrs.eventModel.stats.interested}} {{i18n "discourse_post_event.models.invitee.status.interested"}} -</span>
        <span>{{attrs.eventModel.stats.not_going}} {{i18n "discourse_post_event.models.invitee.status.not_going"}}</span>
        {{#if transformed.isPrivateEvent}}
          <span class="invited">- on {{attrs.eventModel.stats.invited}} users invited</span>
        {{/if}}
      </div>

      {{attach
        widget="button"
        attrs=(hash
          className="show-all btn-small"
          label="discourse_post_event.event_ui.show_all"
          action="showAllInvitees"
          actionParam=(hash postId=attrs.eventModel.id)
        )
      }}
    </div>
    <ul class="event-invitees-avatars">
      {{#each attrs.eventModel.sample_invitees as |invitee|}}
        {{attach
          widget="discourse-post-event-invitee"
          attrs=(hash invitee=invitee)
        }}
      {{/each}}
    </ul>
  `
});
