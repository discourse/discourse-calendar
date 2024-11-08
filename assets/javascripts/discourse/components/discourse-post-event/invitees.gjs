import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse-common/helpers/d-icon";
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

  get statsInfo() {
    const stats = [];
    const visibleStats = this.siteSettings.event_participation_buttons
      .split("|")
      .filter(Boolean);

    if (this.args.event.isPrivate) {
      visibleStats.push("invited");
    }

    visibleStats.forEach((button) => {
      const localeKey = button.replace(" ", "_");
      if (button === "not_going") {
        button = "notGoing";
      }

      const count = this.args.event.stats[button] || 0;

      const label = i18n(
        `discourse_post_event.models.invitee.status.${localeKey}_count`,
        { count }
      );

      stats.push({
        class: `event-status-${localeKey}`,
        label,
      });
    });

    return stats;
  }

  <template>
    {{#unless @event.minimal}}
      {{#if @event.shouldDisplayInvitees}}
        <section class="event__section event-invitees">
          <div class="header">
            <div class="event-invitees-status">
              {{#each this.statsInfo as |info|}}
                <span class={{info.class}}>{{info.label}}</span>
              {{/each}}
            </div>

            <DButton
              class="show-all btn-small"
              @label="discourse_post_event.show_all"
              @action={{this.showAllInvitees}}
            />
          </div>
          <div class="event-invitees-avatars-container">
            {{icon "users"}}
            <ul class="event-invitees-avatars">
              {{#each @event.sampleInvitees as |invitee|}}
                <Invitee @invitee={{invitee}} />
              {{/each}}
            </ul>
          </div>
        </section>
      {{else}}
        <section class="event__section event-invitees no-rsvp">
          <p class="no-rsvp-description">{{i18n
              "discourse_post_event.models.invitee.status.going_count.other"
              count="0"
            }}</p>
        </section>
      {{/if}}
    {{/unless}}
  </template>
}
