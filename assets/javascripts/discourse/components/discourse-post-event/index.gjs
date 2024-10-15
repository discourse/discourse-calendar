import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import routeAction from "discourse/helpers/route-action";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import Creator from "./creator";
import Dates from "./dates";
import Invitees from "./invitees";
import MoreMenu from "./more-menu";
import Status from "./status";
import Url from "./url";

export default class DiscoursePostEvent extends Component {
  @service currentUser;
  @service discoursePostEventApi;
  @service messageBus;

  @action
  setupMessageBus() {
    this.messageBus.subscribe(
      "/discourse-post-event/" + this.args.event.post.topic.id,
      async (msg) => {
        const event = await this.discoursePostEventApi.event(msg.id);
        this.args.event.updateFromEvent(event);
      }
    );
  }

  @action
  teardownMessageBus() {
    this.messageBus.unsubscribe(
      "/discourse-post-event/" + this.args.event.post.topic.id
    );
  }

  get eventStatusLabel() {
    return I18n.t(
      `discourse_calendar.discourse_post_event.models.event.status.${this.args.event.status}.title`
    );
  }

  get eventStatusDescription() {
    return I18n.t(
      `discourse_calendar.discourse_post_event.models.event.status.${this.args.event.status}.description`
    );
  }

  get startsAtMonth() {
    return moment(this.args.event.starts_at).format("MMM");
  }

  get startsAtDay() {
    return moment(this.args.event.starts_at).format("D");
  }

  get eventName() {
    return emojiUnescape(
      escapeExpression(this.args.event.name) || this.args.event.post.topic.title
    );
  }

  get statusClass() {
    return `status ${this.args.event.status}`;
  }

  get isPublicEvent() {
    return this.args.event.status === "public";
  }

  get isStandaloneEvent() {
    return this.args.event.status === "standalone";
  }

  get canActOnEvent() {
    return this.currentUser && this.args.event.can_act_on_discourse_post_event;
  }

  get containerHeight() {
    const datesHeight = 50;
    const urlHeight = 50;
    const headerHeight = 75;
    const bordersHeight = 10;
    const separatorsHeight = 4;
    const margins = 10;

    let widgetHeight =
      datesHeight + headerHeight + bordersHeight + separatorsHeight + margins;

    if (this.args.event.shouldDisplayInvitees && !this.args.event.minimal) {
      widgetHeight += 110;
    }

    if (this.args.event.canUpdateAttendance) {
      widgetHeight += 60;
    }

    if (this.args.event.url) {
      widgetHeight += urlHeight;
    }

    return htmlSafe(`height: ${widgetHeight}px`);
  }

  <template>
    <div
      class={{concatClass
        "discourse-post-event"
        (if @event "is-loaded" "is-loading")
      }}
      style={{this.containerHeight}}
    >
      <div class="discourse-post-event-widget">
        {{#if @event}}
          <header
            class="event-header"
            {{didInsert this.setupMessageBus}}
            {{willDestroy this.teardownMessageBus}}
          >
            <div class="event-date">
              <div class="month">{{this.startsAtMonth}}</div>
              <div class="day">{{this.startsAtDay}}</div>
            </div>
            <div class="event-info">
              <span class="name">
                {{this.eventName}}
              </span>
              <div class="status-and-creators">
                {{#if @event.is_expired}}
                  <span class="status expired">
                    {{i18n
                      "discourse_calendar.discourse_post_event.models.event.expired"
                    }}
                  </span>
                {{else if @event.is_closed}}
                  <span class="status closed">
                    {{i18n
                      "discourse_calendar.discourse_post_event.models.event.closed"
                    }}
                  </span>
                {{else}}
                  <span
                    class={{this.statusClass}}
                    title={{this.eventStatusDescription}}
                  >
                    {{this.eventStatusLabel}}
                  </span>
                {{/if}}
                <span class="separator">·</span>
                <span class="creators">
                  <span class="created-by">{{i18n
                      "discourse_calendar.discourse_post_event.event_ui.created_by"
                    }}</span>
                  <Creator @user={{@event.creator}} />
                </span>
              </div>
            </div>

            <MoreMenu
              @event={{@event}}
              @composePrivateMessage={{routeAction "composePrivateMessage"}}
            />
          </header>

          {{#if @event.canUpdateAttendance}}
            <section class="event-actions">
              <Status @event={{@event}} />
            </section>
          {{/if}}

          {{#if @event.url}}
            <hr />

            <Url @url={{@event.url}} />
          {{/if}}

          <hr />

          <Dates @event={{@event}} />

          {{#unless @event.minimal}}
            {{#if @event.shouldDisplayInvitees}}
              <hr />

              <Invitees @event={{@event}} />
            {{/if}}
          {{/unless}}
        {{/if}}
      </div>
    </div>
  </template>
}
