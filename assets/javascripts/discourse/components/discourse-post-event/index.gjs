import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import replaceEmoji from "discourse/helpers/replace-emoji";
import routeAction from "discourse/helpers/route-action";
import Creator from "./creator";
import Dates from "./dates";
import EventStatus from "./event-status";
import Invitees from "./invitees";
import MoreMenu from "./more-menu";
import Status from "./status";
import Url from "./url";

const StatusSeparator = <template><span class="separator">·</span></template>;

const InfoSection = <template>
  <section class="event__section" ...attributes>
    {{#if @icon}}
      {{icon @icon}}
    {{/if}}

    {{yield}}
  </section>
</template>;

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

  get startsAtMonth() {
    return moment(this.args.event.startsAt).format("MMM");
  }

  get startsAtDay() {
    return moment(this.args.event.startsAt).format("D");
  }

  get eventName() {
    return this.args.event.name || this.args.event.post.topic.title;
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

  get watchingInviteeStatus() {
    return this.args.event.watchingInvitee?.status;
  }

  <template>
    <div
      class={{concatClass
        "discourse-post-event"
        (if @event "is-loaded" "is-loading")
      }}
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
                {{replaceEmoji this.eventName}}
              </span>
              <div class="status-and-creators">
                <PluginOutlet
                  @name="discourse-post-event-status-and-creators"
                  @outletArgs={{hash
                    event=@event
                    Separator=StatusSeparator
                    Status=(component EventStatus event=@event)
                    Creator=(component Creator user=@event.creator)
                  }}
                >
                  <EventStatus @event={{@event}} />
                  <StatusSeparator />
                  <Creator @user={{@event.creator}} />
                </PluginOutlet>
              </div>
            </div>

            <MoreMenu
              @event={{@event}}
              @isStandaloneEvent={{this.isStandaloneEvent}}
              @composePrivateMessage={{routeAction "composePrivateMessage"}}
            />
          </header>

          <PluginOutlet
            @name="discourse-post-event-info"
            @outletArgs={{hash
              event=@event
              Section=(component InfoSection event=@event)
              Url=(component Url url=@event.url)
              Dates=(component Dates event=@event)
              Invitees=(component Invitees event=@event)
              Status=(component Status event=@event)
            }}
          >
            <Url @url={{@event.url}} />
            <Dates @event={{@event}} />
            <Invitees @event={{@event}} />
            {{#if @event.canUpdateAttendance}}
              <Status @event={{@event}} />
            {{/if}}
          </PluginOutlet>
        {{/if}}
      </div>
    </div>
  </template>
}
