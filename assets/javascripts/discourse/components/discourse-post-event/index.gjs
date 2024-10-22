import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import routeAction from "discourse/helpers/route-action";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import i18n from "discourse-common/helpers/i18n";
import Creator from "./creator";
import Dates from "./dates";
import Invitees from "./invitees";
import MoreMenu from "./more-menu";
import Status from "./status";
import Url from "./url";

const Separator = <template><span class="separator">·</span></template>;

export default class DiscoursePostEvent extends Component {
  @service currentUser;
  @service discoursePostEventApi;
  @service messageBus;

  setupMessageBus = modifier(() => {
    const { event } = this.args;
    const path = `/discourse-post-event/${event.post.topic.id}`;
    this.messageBus.subscribe(path, async (msg) => {
      const eventData = await this.discoursePostEventApi.event(msg.id);
      event.updateFromEvent(eventData);
    });

    return () => this.messageBus.unsubscribe(path);
  });

  get eventStatusLabel() {
    return i18n(
      `discourse_calendar.discourse_post_event.models.event.status.${this.args.event.status}.title`
    );
  }

  get eventStatusDescription() {
    return i18n(
      `discourse_calendar.discourse_post_event.models.event.status.${this.args.event.status}.description`
    );
  }

  get startsAtMonth() {
    return moment(this.args.event.startsAt).format("MMM");
  }

  get startsAtDay() {
    return moment(this.args.event.startsAt).format("D");
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
          <header class="event-header" {{this.setupMessageBus}}>
            <div class="event-date">
              <div class="month">{{this.startsAtMonth}}</div>
              <div class="day">{{this.startsAtDay}}</div>
            </div>
            <div class="event-info">
              <span class="name">
                {{this.eventName}}
              </span>
              <div class="status-and-creators">
                <PluginOutlet
                  @name="discourse-post-event-status"
                  @outletArgs={{hash event=@event Separator=Separator}}
                >
                  {{#if @event.isExpired}}
                    <span class="status expired">
                      {{i18n
                        "discourse_calendar.discourse_post_event.models.event.expired"
                      }}
                    </span>
                  {{else if @event.isClosed}}
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
                </PluginOutlet>

                <Separator />

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
