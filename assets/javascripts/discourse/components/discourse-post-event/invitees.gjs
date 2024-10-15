import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import PostEventInvitees from "../modal/post-event-invitees";
import Invitee from "./invitee";

export default class DiscoursePostEventInvitees extends Component {
  @service discoursePostEventApi;
  @service store;
  @service modal;

  @action
  async showAllInvitees(event) {
    try {
      this.modal.show(PostEventInvitees, {
        model: {
          event,
          title: event.title,
          extraClass: event.extraClass,
        },
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <section class="event-invitees">
      <div class="header">
        <div class="event-invitees-status">
          <span>{{@event.stats.going}}
            {{i18n
              "discourse_calendar.discourse_post_event.models.invitee.status.going"
            }}
            -</span>
          <span>{{@event.stats.interested}}
            {{i18n
              "discourse_calendar.discourse_post_event.models.invitee.status.interested"
            }}
            -</span>
          <span>{{@event.stats.notGoing}}
            {{i18n
              "discourse_calendar.discourse_post_event.models.invitee.status.not_going"
            }}</span>
          {{#if @event.isPrivate}}
            <span class="invited">- on
              {{@event.stats.invited}}
              users invited</span>
          {{/if}}
        </div>

        <DButton
          ckass="show-all btn-small"
          @label="discourse_calendar.discourse_post_event.event_ui.show_all"
          @action={{fn this.showAllInvitees @event}}
        />

      </div>
      <ul class="event-invitees-avatars">
        {{#each @event.sampleInvitees as |invitee|}}
          <Invitee @invitee={{invitee}} />
        {{/each}}
      </ul>
    </section>
  </template>
}
