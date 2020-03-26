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

  showAllInvitees(postId) {
    this.store.find("post-event", postId).then(postEvent => {
      showModal("post-event-invitees", {
        model: postEvent
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
      title: this.state.postEvent.name || this.state.postEvent.post.topic.title,
      startsAt: this.state.postEvent.starts_at,
      endsAt: this.state.postEvent.ends_at
    }).generateLink();

    window.open(link, "_blank");
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
      displayPostEventStatus:
        postEvent.creator.id !== this.get("currentUser.id") &&
        postEvent.status !== "standalone",
      postEventStatusLabel: I18n.t(
        `event.post_event_status.${postEvent.status}.title`
      ),
      postEventStatusDescription: I18n.t(
        `event.post_event_status.${postEvent.status}.description`
      ),
      startsAtMonth: moment(postEvent.starts_at).format("MMM"),
      startsAtDay: moment(postEvent.starts_at).format("D"),
      postEventName: postEvent.name || postEvent.post.topic.title,
      statusClass: `status ${postEvent.status}`,
      statusIcon: iconNode(statusIcon)
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
            <span class={{transformed.statusClass}} title={{transformed.postEventStatusDescription}}>
              {{transformed.statusIcon}}
              <span>{{transformed.postEventStatusLabel}}</span>
            </span>
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

      {{#if transformed.displayPostEventStatus}}
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

      {{#if state.postEvent.should_display_invitees}}
        <hr />
        {{attach widget="post-event-invitees" attrs=(hash postEvent=state.postEvent)}}
      {{/if}}

      <footer class="post-event-footer">
        {{attach
          widget="button"
          attrs=(hash
            className="btn-small"
            icon="calendar-day"
            label="event.post_ui.add_to_calendar"
            action="addToGoogleCalendar"
          )
        }}
        {{attach
          widget="button"
          attrs=(hash
            className="btn-small"
            icon="envelope"
            label="event.post_ui.send_pm_to_creator"
            action="sendPMToCreator"
          )
        }}
      </footer>
    {{/if}}
  `
});
