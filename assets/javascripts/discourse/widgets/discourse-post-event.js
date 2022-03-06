import I18n from "I18n";
import TextLib, { emojiUnescape } from "discourse/lib/text";
import { exportEntity } from "discourse/lib/export-csv";
import cleanTitle from "discourse/plugins/discourse-calendar/lib/clean-title";
import { dasherize } from "@ember/string";
import EmberObject from "@ember/object";
import showModal from "discourse/lib/show-modal";
import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import { routeAction } from "discourse/helpers/route-action";
import { buildParams, replaceRaw } from "../../lib/raw-event-helper";
import bootbox from "bootbox";

export default createWidget("discourse-post-event", {
  tagName: "div.discourse-post-event-widget",

  buildKey: (attrs) => `discourse-post-event-${attrs.id}`,

  buildClasses() {
    if (this.state.event) {
      return ["has-discourse-post-event"];
    }
  },

  inviteUserOrGroup(postId) {
    this.store.find("discourse-post-event-event", postId).then((eventModel) => {
      showModal("discourse-post-event-invite-user-or-group", {
        model: eventModel,
      });
    });
  },

  showAllInvitees(params) {
    const postId = params.postId;
    const title = params.title || "title_invited";
    const extraClass = params.extraClass || "invited";
    const name = "discourse-post-event-invitees";

    this.store.find("discourse-post-event-event", postId).then((eventModel) => {
      showModal(name, {
        model: eventModel,
        title: `discourse_post_event.invitees_modal.${title}`,
        modalClass: [`${dasherize(name).toLowerCase()}-modal`, extraClass].join(
          " "
        ),
      });
    });
  },

  editPostEvent(postId) {
    this.store.find("discourse-post-event-event", postId).then((eventModel) => {
      showModal("discourse-post-event-builder", {
        model: { eventModel, topicId: eventModel.post.topic.id },
      });
    });
  },

  closeEvent(eventModel) {
    bootbox.confirm(
      I18n.t("discourse_post_event.builder_modal.confirm_close"),
      I18n.t("no_value"),
      I18n.t("yes_value"),
      (confirmed) => {
        if (confirmed) {
          return this.store.find("post", eventModel.id).then((post) => {
            const raw = post.raw;
            const startsAt = eventModel.starts_at
              ? moment(eventModel.starts_at)
              : moment();
            const eventParams = buildParams(
              moment().isBefore(startsAt) ? moment() : startsAt,
              moment().isBefore(startsAt)
                ? moment().add(1, "minute")
                : moment(),
              eventModel,
              this.siteSettings
            );
            const newRaw = replaceRaw(eventParams, raw);

            if (newRaw) {
              const props = {
                raw: newRaw,
                edit_reason: I18n.t("discourse_post_event.edit_reason"),
              };

              return TextLib.cookAsync(newRaw).then((cooked) => {
                props.cooked = cooked.string;
                return post.save(props);
              });
            }
          });
        }
      }
    );
  },

  changeWatchingInviteeStatus(status) {
    if (this.state.eventModel.watching_invitee) {
      this.store.update(
        "discourse-post-event-invitee",
        this.state.eventModel.watching_invitee.id,
        { status, post_id: this.state.eventModel.id }
      );
    } else {
      this.store
        .createRecord("discourse-post-event-invitee")
        .save({ post_id: this.state.eventModel.id, status });
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
    showModal("discourse-post-event-bulk-invite", {
      model: { eventModel },
    });
  },

  sendPMToCreator() {
    const router = this.register.lookup("service:router")._router;
    routeAction(
      "composePrivateMessage",
      router,
      EmberObject.create(this.state.eventModel.creator),
      EmberObject.create(this.state.eventModel.post)
    ).call();
  },

  addToCalendar() {
    const event = this.state.eventModel;
    this.attrs.api.downloadCalendar(event.name || event.post.topic.title, [
      {
        startsAt: event.starts_at,
        endsAt: event.ends_at,
      },
    ]);
  },

  transform() {
    const eventModel = this.state.eventModel;

    return {
      eventStatusLabel: I18n.t(
        `discourse_post_event.models.event.status.${eventModel.status}.title`
      ),
      eventStatusDescription: I18n.t(
        `discourse_post_event.models.event.status.${eventModel.status}.description`
      ),
      startsAtMonth: moment(eventModel.starts_at).format("MMM"),
      startsAtDay: moment(eventModel.starts_at).format("D"),
      eventName: emojiUnescape(
        eventModel.name ||
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
                  {{i18n "discourse_post_event.models.event.expired"}}
                </span>
              {{else}}
                <span class={{transformed.statusClass}} title={{transformed.eventStatusDescription}}>
                  {{transformed.eventStatusLabel}}
                </span>
              {{/if}}
              <span class="separator">·</span>
            {{/unless}}
            <span class="creators">
              <span class="created-by">{{i18n "discourse_post_event.event_ui.created_by"}}</span>
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

      {{#if state.eventModel.should_display_invitees}}
        <hr />

        {{attach widget="discourse-post-event-invitees"
          attrs=(hash eventModel=state.eventModel)
        }}
      {{/if}}
    {{/if}}
  `,

  _cleanTopicTitle(topicTitle, startsAt) {
    const cleaned = cleanTitle(topicTitle, startsAt);
    if (cleaned) {
      return topicTitle.replace(cleaned, "");
    }

    return topicTitle;
  },
});
