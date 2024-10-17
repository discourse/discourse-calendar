import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { downloadCalendar } from "discourse/lib/download-calendar";
import { exportEntity } from "discourse/lib/export-csv";
import { cook } from "discourse/lib/text";
import i18n from "discourse-common/helpers/i18n";
import { getAbsoluteURL } from "discourse-common/lib/get-url";
import I18n from "I18n";
import DMenu from "float-kit/components/d-menu";
import { buildParams, replaceRaw } from "../../lib/raw-event-helper";
import PostEventBuilder from "../modal/post-event-builder";
import PostEventBulkInvite from "../modal/post-event-bulk-invite";
import PostEventInviteUserOrGroup from "../modal/post-event-invite-user-or-group";

export default class DiscoursePostEventMoreMenu extends Component {
  @service appEvents;
  @service currentUser;
  @service dialog;
  @service discoursePostEventApi;
  @service modal;
  @service router;
  @service siteSettings;
  @service store;

  get expiredOrClosed() {
    return this.args.event.isExpired || this.args.event.isClosed;
  }

  get canActOnEvent() {
    return this.currentUser && this.args.event.canActOnDiscoursePostEvent;
  }

  get canInvite() {
    return (
      !this.expiredOrClosed && this.canActOnEvent && this.args.event.isPublic
    );
  }

  get canLeave() {
    return this.args.event.watchingInvitee && this.args.event.isPublic;
  }

  get canSeeUpcomingEvents() {
    return !this.args.event.isClosed && this.args.event.recurrence;
  }

  get canBulkInvite() {
    return !this.expiredOrClosed && !this.args.event.isStandalone;
  }

  @action
  addToCalendar() {
    this.menuApi.close();

    const event = this.args.event;

    downloadCalendar(
      event.name || event.post.topic.title,
      [
        {
          startsAt: event.startsAt,
          endsAt: event.endsAt,
        },
      ],
      {
        recurrenceRule: event.recurrenceRule,
        location: event.url,
        details: getAbsoluteURL(event.post.url),
      }
    );
  }

  @action
  sendPMToCreator() {
    this.menuApi.close();

    this.args.composePrivateMessage(
      EmberObject.create(this.args.event.creator),
      EmberObject.create(this.args.event.post)
    );
  }

  @action
  upcomingEvents() {
    this.router.transitionTo("discourse-post-event-upcoming-events");
  }

  @action
  registerMenuApi(api) {
    this.menuApi = api;
  }

  @action
  async inviteUserOrGroup(event) {
    this.menuApi.close();

    try {
      this.modal.show(PostEventInviteUserOrGroup, {
        model: { event },
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async leaveEvent(event) {
    this.menuApi.close();

    try {
      const invitee = event.watchingInvitee;

      await this.discoursePostEventApi.leaveEvent(event, invitee);

      this.appEvents.trigger("calendar:invitee-left-event", {
        invitee,
        postId: event.id,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  exportPostEvent(event) {
    this.menuApi.close();

    exportEntity("post_event", {
      name: "post_event",
      id: event.id,
    });
  }

  @action
  bulkInvite(event) {
    this.menuApi.close();

    this.modal.show(PostEventBulkInvite, {
      model: { event },
    });
  }

  @action
  async openEvent(event) {
    this.menuApi.close();

    this.dialog.yesNoConfirm({
      message: I18n.t(
        "discourse_calendar.discourse_post_event.builder_modal.confirm_open"
      ),
      didConfirm: () => {
        return this.store.find("post", event.id).then((post) => {
          event.closed = false;

          const eventParams = buildParams(
            event.startsAt,
            event.endsAt,
            event,
            this.siteSettings
          );

          const newRaw = replaceRaw(eventParams, post.raw);

          if (newRaw) {
            const props = {
              raw: newRaw,
              edit_reason: I18n.t(
                "discourse_calendar.discourse_post_event.edit_reason_opened"
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
  }

  @action
  async editPostEvent(event) {
    this.menuApi.close();

    this.modal.show(PostEventBuilder, {
      model: {
        event,
      },
    });
  }

  @action
  async closeEvent(event) {
    this.menuApi.close();

    this.dialog.yesNoConfirm({
      message: I18n.t(
        "discourse_calendar.discourse_post_event.builder_modal.confirm_close"
      ),
      didConfirm: () => {
        return this.store.find("post", event.id).then((post) => {
          event.closed = true;

          const eventParams = buildParams(
            event.startsAt,
            event.endsAt,
            event,
            this.siteSettings
          );

          const newRaw = replaceRaw(eventParams, post.raw);

          if (newRaw) {
            const props = {
              raw: newRaw,
              edit_reason: I18n.t(
                "discourse_calendar.discourse_post_event.edit_reason_closed"
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
  }

  <template>
    <DMenu
      @identifier="discourse-post-event-more-menu"
      @triggerClass="more-dropdown"
      @icon="ellipsis-h"
      @onRegisterApi={{this.registerMenuApi}}
    >
      <:content>
        <DropdownMenu as |dropdown|>
          {{#unless this.expiredOrClosed}}
            <dropdown.item class="add-to-calendar">
              <DButton
                @icon="file"
                @label="discourse_calendar.discourse_post_event.event_ui.add_to_calendar"
                @action={{this.addToCalendar}}
              />
            </dropdown.item>
          {{/unless}}

          {{#if this.currentUser}}
            <dropdown.item class="send-pm-to-creator">
              <DButton
                @icon="envelope"
                class="btn-transparent"
                @translatedLabel={{i18n
                  "discourse_calendar.discourse_post_event.event_ui.send_pm_to_creator"
                  (hash username=@event.creator.username)
                }}
                @action={{this.sendPMToCreator}}
              />
            </dropdown.item>
          {{/if}}

          {{#if this.canInvite}}
            <dropdown.item class="invite-user-or-group">
              <DButton
                @icon="user-plus"
                class="btn-transparent"
                @translatedLabel={{i18n
                  "discourse_calendar.discourse_post_event.event_ui.invite"
                }}
                @action={{fn this.inviteUserOrGroup @event}}
              />
            </dropdown.item>
          {{/if}}

          {{#if this.canLeave}}
            <dropdown.item class="leave-event">
              <DButton
                @icon="times"
                class="btn-transparent"
                @translatedLabel={{i18n
                  "discourse_calendar.discourse_post_event.event_ui.leave"
                }}
                @action={{fn this.leaveEvent @event}}
              />
            </dropdown.item>
          {{/if}}

          {{#if this.canSeeUpcomingEvents}}
            <dropdown.item class="upcoming-events">
              <DButton
                @icon="far-calendar-plus"
                class="btn-transparent"
                @translatedLabel={{i18n
                  "discourse_post_event.event_ui.upcoming_events"
                }}
                @action={{this.upcomingEvents}}
              />
            </dropdown.item>
          {{/if}}

          {{#if this.canActOnEvent}}
            <dropdown.divider />

            <dropdown.item class="export-event">
              <DButton
                @icon="file-csv"
                class="btn-transparent"
                @label="discourse_calendar.discourse_post_event.event_ui.export_event"
                @action={{fn this.exportPostEvent @event}}
              />
            </dropdown.item>

            {{#if this.canBulkInvite}}
              <dropdown.item class="bulk-invite">
                <DButton
                  @icon="file-upload"
                  class="btn-transparent"
                  @label="discourse_calendar.discourse_post_event.event_ui.bulk_invite"
                  @action={{fn this.bulkInvite @event}}
                />
              </dropdown.item>
            {{/if}}

            {{#if @event.isClosed}}
              <dropdown.item class="open-event">
                <DButton
                  @icon="unlock"
                  class="btn-transparent"
                  @label="discourse_calendar.discourse_post_event.event_ui.open_event"
                  @action={{fn this.openEvent @event}}
                />
              </dropdown.item>
            {{else}}
              <dropdown.item class="edit-event">
                <DButton
                  @icon="pencil-alt"
                  class="btn-transparent"
                  @label="discourse_calendar.discourse_post_event.event_ui.edit_event"
                  @action={{fn this.editPostEvent @event}}
                />
              </dropdown.item>

              {{#unless @event.isExpired}}
                <dropdown.item class="close-event">
                  <DButton
                    @icon="times"
                    @label="discourse_calendar.discourse_post_event.event_ui.close_event"
                    @action={{fn this.closeEvent @event}}
                    class="btn-transparent btn-danger"
                  />
                </dropdown.item>
              {{/unless}}
            {{/if}}
          {{/if}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
