import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";
import PostEventInvitees from "../modal/post-event-invitees";
import Invitee from "./invitee";

export default class DiscoursePostEventInvitees extends Component {
  @service modal;
  @service siteSettings;

  @action
  showAllInvitees() {
    this.modal.show(PostEventInvitees, {
      model: {
        event: this.args.event,
        title: this.args.event.title,
        extraClass: this.args.event.extraClass,
      },
    });
  }

  get statusButtons() {
    const buttons = [];
    const allowed_buttons =
      this.siteSettings.event_participation_buttons.split("|");

    if (this.args.event.isPrivate) {
      allowed_buttons.push("invited");
    }

    allowed_buttons.forEach((button) => {
      const localeKey = button.replace(" ", "_");
      if (button === "not_going") {
        button = "notGoing";
      }

      const count = this.args.event.stats[button] || 0;

      const name = i18n(
        `discourse_calendar.discourse_post_event.models.invitee.status.${localeKey}_count`,
        {
          count,
        }
      );

      const className = `event-status-${localeKey}`;

      buttons.push({
        class: className,
        name,
      });
    });

    return buttons;
  }

  <template>
    <section class="event-invitees">
      <div class="header">
        <div class="event-invitees-status">
          {{#each this.statusButtons as |button|}}
            <span class={{button.class}}>{{button.name}}</span>
          {{/each}}
        </div>

        <DButton
          class="show-all btn-small"
          @label="discourse_calendar.discourse_post_event.event_ui.show_all"
          @action={{this.showAllInvitees}}
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
