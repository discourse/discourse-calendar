import getOwner from "@ember/application";
import EmberObject from "@ember/object";
import { exportEntity } from "discourse/lib/export-csv";
import { cook, emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import { getAbsoluteURL } from "discourse-common/lib/get-url";
import I18n from "I18n";
import PostEventBuilder from "../components/modal/post-event-builder";
import PostEventBulkInvite from "../components/modal/post-event-bulk-invite";
import PostEventInviteUserOrGroup from "../components/modal/post-event-invite-user-or-group";
import PostEventInvitees from "../components/modal/post-event-invitees";
import cleanTitle from "../lib/clean-title";
import { buildParams, replaceRaw } from "../lib/raw-event-helper";

const DEFAULT_REMINDER = {
  type: "notification",
  value: 15,
  unit: "minutes",
  period: "before",
};

export default createWidget("discourse-post-event", {
  tagName: "div.discourse-post-event-widget",
  services: ["dialog", "store", "modal", "currentUser", "siteSettings"],

  buildKey: (attrs) => `discourse-post-event-${attrs.id}`,

  buildClasses() {
    if (this.state.event) {
      return ["has-discourse-post-event"];
    }
  },

  inviteUserOrGroup(postId) {
    this.store.find("discourse-post-event-event", postId).then((eventModel) => {
      this.modal.show(PostEventInviteUserOrGroup, {
        model: { event: eventModel },
      });
    });
  },

  showAllInvitees(params) {
    this.store
      .find("discourse-post-event-event", params.postId)
      .then((eventModel) => {
        this.modal.show(PostEventInvitees, {
          model: {
            event: eventModel,
            title: params.title,
            extraClass: params.extraClass,
          },
        });
      });
  },

  editPostEvent(postId) {
    this.store.find("discourse-post-event-event", postId).then((eventModel) => {
      this.modal.show(PostEventBuilder, {
        model: {
          event: eventModel,
          updateCustomField: (field, value) =>
            updateCustomField(eventModel, field, value),
          updateEventStatus: (status) => updateEventStatus(eventModel, status),
          updateEventRawInvitees: (rawInvitees) =>
            updateEventRawInvitees(eventModel, rawInvitees),
          removeReminder: (reminder) => removeReminder(eventModel, reminder),
          addReminder: () => addReminder(eventModel),
          onChangeDates: (changes) => onChangeDates(eventModel, changes),
          updateTimezone: (newTz, startsAt, endsAt) =>
            updateTimezone(eventModel, newTz, startsAt, endsAt),
        },
      });
    });
  },

  closeEvent(eventModel) {
    this.dialog.yesNoConfirm({
      message: I18n.t(
        "discourse_calendar.discourse_post_event.builder_modal.confirm_close"
      ),
      didConfirm: () => {
        return this.store.find("post", eventModel.id).then((post) => {
          const raw = post.raw;
          const startsAt = eventModel.starts_at
            ? moment(eventModel.starts_at)
            : moment();
          const eventParams = buildParams(
            moment().isBefore(startsAt) ? moment() : startsAt,
            moment().isBefore(startsAt) ? moment().add(1, "minute") : moment(),
            eventModel,
            this.siteSettings
          );
          const newRaw = replaceRaw(eventParams, raw);

          if (newRaw) {
            const props = {
              raw: newRaw,
              edit_reason: I18n.t(
                "discourse_calendar.discourse_post_event.edit_reason"
              ),
            };

            return cook(newRaw).then((cooked) => {
              props.cooked = cooked.string;
              return post.save(props);
            });
          }
        });
      },
    });
  },

  changeWatchingInviteeStatus(status) {
    if (this.state.eventModel.watching_invitee) {
      const currentStatus = this.state.eventModel.watching_invitee.status;
      let newStatus = status;
      if (status === currentStatus && status === "interested") {
        newStatus = null;
      }
      this.store.update(
        "discourse-post-event-invitee",
        this.state.eventModel.watching_invitee.id,
        { status: newStatus, post_id: this.state.eventModel.id }
      );

      this.appEvents.trigger("calendar:update-invitee-status", {
        status: newStatus,
        postId: this.state.eventModel.id,
      });
    } else {
      this.store
        .createRecord("discourse-post-event-invitee")
        .save({ post_id: this.state.eventModel.id, status });
      this.appEvents.trigger("calendar:create-invitee-status", {
        status,
        postId: this.state.eventModel.id,
      });
    }
  },

  defaultState(attrs) {
    return {
      eventModel: attrs.eventModel,
    };
  },

  exportPostEvent(postId) {
    exportEntity("post_event", {
      name: "post_event",
      id: postId,
    });
  },

  bulkInvite(eventModel) {
    this.modal.show(PostEventBulkInvite, {
      model: { event: eventModel },
    });
  },

  sendPMToCreator() {
    getOwner(this)
      .lookup("route:application")
      .send(
        "composePrivateMessage",
        EmberObject.create(this.state.eventModel.creator),
        EmberObject.create(this.state.eventModel.post)
      );
  },

  addToCalendar() {
    const event = this.state.eventModel;
    this.attrs.api.downloadCalendar(
      event.name || event.post.topic.title,
      [
        {
          startsAt: event.starts_at,
          endsAt: event.ends_at,
        },
      ],
      {
        recurrenceRule: event.recurrence_rule,
        location: event.url,
        details: getAbsoluteURL(event.post.url),
      }
    );
  },

  upcomingEvents() {
    const router = this.register.lookup("service:router")._router;
    router.transitionTo("discourse-post-event-upcoming-events");
  },

  leaveEvent(postId) {
    this.store
      .findAll("discourse-post-event-invitee", {
        post_id: postId,
      })
      .then((invitees) => {
        let invitee = invitees.find(
          (inv) => inv.id === this.state.eventModel.watching_invitee.id
        );
        this.appEvents.trigger("calendar:invitee-left-event", {
          invitee,
          postId,
        });
        invitee.destroyRecord();
      });
  },

  transform() {
    const eventModel = this.state.eventModel;

    return {
      eventStatusLabel: I18n.t(
        `discourse_calendar.discourse_post_event.models.event.status.${eventModel.status}.title`
      ),
      eventStatusDescription: I18n.t(
        `discourse_calendar.discourse_post_event.models.event.status.${eventModel.status}.description`
      ),
      startsAtMonth: moment(eventModel.starts_at).format("MMM"),
      startsAtDay: moment(eventModel.starts_at).format("D"),
      eventName: emojiUnescape(
        escapeExpression(eventModel.name) ||
          this._cleanTopicTitle(
            eventModel.post.topic.title,
            eventModel.starts_at
          )
      ),
      statusClass: `status ${eventModel.status}`,
      isPublicEvent: eventModel.status === "public",
      isStandaloneEvent: eventModel.status === "standalone",
      canActOnEvent:
        this.currentUser &&
        this.state.eventModel.can_act_on_discourse_post_event,
    };
  },

  template: hbs`
    {{#if state.eventModel}}
      <header class="event-header">
        <div class="event-date">
          <div class="month">{{transformed.startsAtMonth}}</div>
          <div class="day">{{transformed.startsAtDay}}</div>
        </div>
        <div class="event-info">
          <span class="name">
            {{{transformed.eventName}}}
          </span>
          <div class="status-and-creators">
            {{#unless transformed.isStandaloneEvent}}
              {{#if state.eventModel.is_expired}}
                <span class="status expired">
                  {{i18n "discourse_calendar.discourse_post_event.models.event.expired"}}
                </span>
              {{else}}
                <span class={{transformed.statusClass}} title={{transformed.eventStatusDescription}}>
                  {{transformed.eventStatusLabel}}
                </span>
              {{/if}}
              <span class="separator">·</span>
            {{/unless}}
            <span class="creators">
              <span class="created-by">{{i18n "discourse_calendar.discourse_post_event.event_ui.created_by"}}</span>
              {{attach widget="discourse-post-event-creator" attrs=(hash user=state.eventModel.creator)}}
            </span>
          </div>
        </div>

        {{attach
          widget="more-dropdown"
          attrs=(hash
            canActOnEvent=this.transformed.canActOnEvent
            isPublicEvent=this.transformed.isPublicEvent
            eventModel=state.eventModel
          )
        }}
      </header>

      {{#if state.eventModel.can_update_attendance}}
        <section class="event-actions">
          {{attach
            widget="discourse-post-event-status"
            attrs=(hash
              watchingInvitee=this.state.eventModel.watching_invitee
              minimal=this.state.eventModel.minimal
            )
          }}
        </section>
      {{/if}}

      {{#if this.state.eventModel.url}}
        <hr />

        {{attach widget="discourse-post-event-url"
          attrs=(hash
            url=this.state.eventModel.url
          )
        }}
      {{/if}}

      <hr />

      {{attach widget="discourse-post-event-dates"
        attrs=(hash
          localDates=attrs.localDates
          eventModel=state.eventModel
        )
      }}

      {{#unless state.eventModel.minimal}}
        {{#if state.eventModel.should_display_invitees}}
          <hr />

          {{attach widget="discourse-post-event-invitees"
            attrs=(hash eventModel=state.eventModel)
          }}
        {{/if}}
      {{/unless}}
    {{/if}}
  `,

  _cleanTopicTitle(topicTitle, startsAt) {
    topicTitle = escapeExpression(topicTitle);
    const cleaned = cleanTitle(topicTitle, startsAt);
    if (cleaned) {
      return topicTitle.replace(cleaned, "");
    }

    return topicTitle;
  },
});

function replaceTimezone(val, newTimezone) {
  return moment.tz(val.format("YYYY-MM-DDTHH:mm"), newTimezone);
}
export function updateEventStatus(event, status) {
  return event.set("status", status);
}
export function updateEventRawInvitees(event, rawInvitees) {
  return event.set("raw_invitees", rawInvitees);
}
export function updateCustomField(event, field, value) {
  event.custom_fields.set(field, value);
}
export function removeReminder(event, reminder) {
  return event.reminders.removeObject(reminder);
}
export function addReminder(event) {
  if (!event.reminders) {
    event.set("reminders", []);
  }
  event.reminders.pushObject(Object.assign({}, DEFAULT_REMINDER));
}
export function onChangeDates(event, changes) {
  return event.setProperties({ starts_at: changes.from, ends_at: changes.to });
}
export function updateTimezone(event, newTz, startsAt, endsAt) {
  return event.setProperties({
    timezone: newTz,
    starts_at: replaceTimezone(startsAt, newTz),
    ends_at: endsAt && replaceTimezone(endsAt, newTz),
  });
}
