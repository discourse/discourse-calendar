import cleanTitle from "discourse/plugins/discourse-calendar/lib/clean-title";
import { dasherize } from "@ember/string";
import EmberObject from "@ember/object";
import showModal from "discourse/lib/show-modal";
import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import GoogleCalendar from "discourse/plugins/discourse-calendar/discourse/lib/google-calendar";
import { routeAction } from "discourse/helpers/route-action";
import { iconNode } from "discourse-common/lib/icon-library";

export default createWidget("post-event", {
  tagName: "div.post-event",

  buildKey: attrs => `post-event-${attrs.id}`,

  buildAttributes(attrs) {
    return { style: `height:${attrs.widgetHeight}px` };
  },

  buildClasses() {
    if (this.state.postEvent) {
      return ["has-post-event"];
    }
  },

  inviteUserOrGroup(postId) {
    this.store.find("post-event", postId).then(postEvent => {
      showModal("invite-user-or-group", {
        model: postEvent
      });
    });
  },

  showAllInvitees(params) {
    const postId = params.postId;
    const title = params.title || "title_invited";
    const extraClass = params.extraClass || "invited";
    const name = "post-event-invitees";

    this.store.find("post-event", postId).then(postEvent => {
      showModal(name, {
        model: postEvent,
        title: `event.post_event_invitees_modal.${title}`,
        modalClass: [`${dasherize(name).toLowerCase()}-modal`, extraClass].join(
          " "
        )
      });
    });
  },

  editPostEvent(postId) {
    this.store.find("post-event", postId).then(postEvent => {
      showModal("event-ui-builder", {
        model: postEvent,
        modalClass: "event-ui-builder-modal"
      });
    });
  },

  changeWatchingInviteeStatus(status) {
    if (this.state.postEvent.watching_invitee) {
      this.store.update("invitee", this.state.postEvent.watching_invitee.id, {
        status
      });
    } else {
      this.store
        .createRecord("invitee")
        .save({ post_id: this.state.postEvent.id, status });
    }
  },

  defaultState(attrs) {
    return {
      postEvent: attrs.postEvent
    };
  },

  sendPMToCreator() {
    const router = this.register.lookup("service:router")._router;
    routeAction(
      "composePrivateMessage",
      router,
      EmberObject.create(this.state.postEvent.creator),
      EmberObject.create(this.state.postEvent.post)
    ).call();
  },

  addToGoogleCalendar() {
    const link = GoogleCalendar.create({
      title:
        this.state.postEvent.name ||
        this._cleanTopicTitle(
          this.state.postEvent.post.topic.title,
          this.state.postEvent.starts_at
        ),
      startsAt: this.state.postEvent.starts_at,
      endsAt: this.state.postEvent.ends_at
    }).generateLink();

    window.open(link, "_blank", "noopener");
  },

  transform() {
    const postEvent = this.state.postEvent;

    let statusIcon = "times";
    if (postEvent.status === "private") {
      statusIcon = "lock";
    }
    if (postEvent.status === "public") {
      statusIcon = "unlock";
    }

    return {
      postEventStatusLabel: I18n.t(
        `event.post_event_status.${postEvent.status}.title`
      ),
      postEventStatusDescription: I18n.t(
        `event.post_event_status.${postEvent.status}.description`
      ),
      startsAtMonth: moment(postEvent.starts_at).format("MMM"),
      startsAtDay: moment(postEvent.starts_at).format("D"),
      postEventName:
        postEvent.name ||
        this._cleanTopicTitle(postEvent.post.topic.title, postEvent.starts_at),
      statusClass: `status ${postEvent.status}`,
      statusIcon: iconNode(statusIcon),
      isPublicEvent: postEvent.status === "public",
      isStandaloneEvent: postEvent.status === "standalone"
    };
  },

  template: hbs`
    {{#if state.postEvent}}
      <header class="post-event-header">
        <div class="post-event-date">
          <div class="month">{{transformed.startsAtMonth}}</div>
          <div class="day">{{transformed.startsAtDay}}</div>
        </div>
        <div class="post-event-info">
          <div class="status-and-name">
            {{#if state.postEvent.is_expired}}
              {{#unless transformed.isStandaloneEvent}}
                <span class="status expired">
                  {{i18n "event.expired"}}
                </span>
              {{else}}
                <span class={{transformed.statusClass}} title={{transformed.postEventStatusDescription}}>
                  {{transformed.statusIcon}}
                  <span>{{transformed.postEventStatusLabel}}</span>
                </span>
              {{/unless}}
            {{else}}
              <span class={{transformed.statusClass}} title={{transformed.postEventStatusDescription}}>
                {{transformed.statusIcon}}
                <span>{{transformed.postEventStatusLabel}}</span>
              </span>
            {{/if}}
            <span class="name">
              {{transformed.postEventName}}
            </span>
          </div>
          <span class="creators">
            Created by {{attach widget="post-event-creator" attrs=(hash user=state.postEvent.creator)}}
          </span>
        </div>

        {{#if state.postEvent.can_act_on_post_event}}
          <div class="actions">
            {{attach
              widget="button"
              attrs=(hash
                className="btn-small"
                icon="pencil-alt"
                action="editPostEvent"
                actionParam=state.postEvent.id
              )
            }}
          </div>
        {{/if}}
      </header>

      {{#if state.postEvent.can_update_attendance}}
        <section class="post-event-actions">
        {{attach
          widget="post-event-status"
          attrs=(hash
            watchingInvitee=this.state.postEvent.watching_invitee
          )
        }}
        </section>
      {{/if}}

      <hr />

      {{attach widget="post-event-dates" attrs=(hash localDates=attrs.localDates postEvent=state.postEvent)}}

      {{#unless state.postEvent.is_expired}}
      {{#if state.postEvent.should_display_invitees}}
        <hr />
        {{attach widget="post-event-invitees" attrs=(hash postEvent=state.postEvent)}}
      {{/if}}
      {{/unless}}

      <footer class="post-event-footer">
        {{#unless state.postEvent.is_expired}}
        {{attach
          widget="button"
          attrs=(hash
            className="btn-small"
            icon="calendar-day"
            label="event.post_ui.add_to_calendar"
            action="addToGoogleCalendar"
          )
        }}
        {{/unless}}

        {{attach
          widget="button"
          attrs=(hash
            className="btn-small"
            icon="envelope"
            label="event.post_ui.send_pm_to_creator"
            action="sendPMToCreator"
          )
        }}

        {{#unless state.postEvent.is_expired}}
        {{#if state.postEvent.can_act_on_post_event}}
        {{#if transformed.isPublicEvent}}
          {{attach
            widget="button"
            attrs=(hash
              className="btn-small"
              icon="user-plus"
              label="event.post_ui.invite"
              action="inviteUserOrGroup"
              actionParam=state.postEvent.id
            )
          }}
        {{/if}}
        {{/if}}
        {{/unless}}
      </footer>
    {{/if}}
  `,

  _cleanTopicTitle(topicTitle, startsAt) {
    const cleaned = cleanTitle(topicTitle, startsAt);
    if (cleaned) {
      return topicTitle.replace(cleaned, "");
    }

    return topicTitle;
  }
});
