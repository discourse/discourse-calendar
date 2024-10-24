import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import DMenu from "float-kit/components/d-menu";

export default class DiscoursePostEventStatus extends Component {
  @service appEvents;
  @service discoursePostEventApi;
  @service siteSettings;

  get watchingInviteeStatus() {
    return this.args.event.watchingInvitee?.status;
  }

  get inviteeButtonText() {
    let status = this.args.event.watchingInvitee?.status;
    return status === "going"
      ? "discourse_post_event.models.invitee.status.going"
      : status === "interested"
      ? "discourse_post_event.models.invitee.status.interested"
      : status === "not_going"
      ? "discourse_post_event.models.invitee.status.not_going"
      : "discourse_post_event.models.invitee.status.not_set";
  }

  get inviteButtonIcon() {
    let status = this.args.event.watchingInvitee?.status;
    return status === "going"
      ? "check"
      : status === "interested"
      ? "star"
      : "question";
  }

  get eventButtons() {
    return this.siteSettings.event_participation_buttons.split("|");
  }

  get showGoingButton() {
    return !!this.eventButtons.find((button) => button === "going");
  }

  get showInterestedButton() {
    return !!this.eventButtons.find((button) => button === "interested");
  }

  get showNotGoingButton() {
    return !!this.eventButtons.find((button) => button === "not going");
  }

  get canLeave() {
    return this.args.event.watchingInvitee && this.args.event.isPublic;
  }

  @action
  async leaveEvent() {
    try {
      const invitee = this.args.event.watchingInvitee;

      await this.discoursePostEventApi.leaveEvent(this.args.event, invitee);

      this.appEvents.trigger("calendar:invitee-left-event", {
        invitee,
        postId: this.args.event.id,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async updateEventAttendance(status) {
    try {
      await this.discoursePostEventApi.updateEventAttendance(this.args.event, {
        status,
      });

      this.appEvents.trigger("calendar:update-invitee-status", {
        status,
        postId: this.args.event.id,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async joinEventWithStatus(status) {
    try {
      await this.discoursePostEventApi.joinEvent(this.args.event, {
        status,
      });

      this.appEvents.trigger("calendar:create-invitee-status", {
        status,
        postId: this.args.event.id,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async changeWatchingInviteeStatus(status) {
    if (this.args.event.watchingInvitee) {
      const currentStatus = this.args.event.watchingInvitee.status;
      if (this.canLeave) {
        if (status === currentStatus) {
          await this.leaveEvent();
        } else {
          await this.updateEventAttendance(status);
        }
      } else {
        if (status === currentStatus) {
          status = null;
        }

        await this.updateEventAttendance(status);
      }
    } else {
      await this.joinEventWithStatus(status);
    }
  }

  <template>
    <div
      class={{concatClass
        "event-status"
        (if
          this.watchingInviteeStatus
          (concat "status-" this.watchingInviteeStatus)
        )
      }}
    >
      <DMenu @identifier="discourse-post-event-status" @title="Event Status">
        <:trigger>
          {{icon this.inviteButtonIcon}}
          <span class="d-button-label event-status-label">{{i18n
              this.inviteeButtonText
            }}</span>
          {{icon "angle-down"}}
        </:trigger>
        <:content>
          <DropdownMenu as |dropdown|>
            {{#if this.showGoingButton}}
              {{#unless @event.minimal}}
                <dropdown.item>
                  <PluginOutlet
                    @name="discourse-post-event-status-going-button"
                    @outletArgs={{hash
                      event=@event
                      markAsGoing=(fn this.changeWatchingInviteeStatus "going")
                    }}
                  >
                    <DButton
                      class="going-button"
                      @icon="check"
                      @label="discourse_post_event.models.invitee.status.going"
                      @action={{fn this.changeWatchingInviteeStatus "going"}}
                    />
                  </PluginOutlet>
                </dropdown.item>
              {{/unless}}
            {{/if}}

            {{#if this.showInterestedButton}}
              <dropdown.item>
                <PluginOutlet
                  @name="discourse-post-event-status-interested-button"
                  @outletArgs={{hash
                    event=@event
                    markAsInterested=(fn
                      this.changeWatchingInviteeStatus "interested"
                    )
                  }}
                >
                  <DButton
                    class="interested-button"
                    @icon="star"
                    @label="discourse_post_event.models.invitee.status.interested"
                    @action={{fn this.changeWatchingInviteeStatus "interested"}}
                  />
                </PluginOutlet>
              </dropdown.item>
            {{/if}}

            {{#if this.showNotGoingButton}}
              {{#unless @event.minimal}}
                <dropdown.item>
                  <PluginOutlet
                    @name="discourse-post-event-status-not-going-button"
                    @outletArgs={{hash
                      event=@event
                      markAsNotGoing=(fn
                        this.changeWatchingInviteeStatus "not_going"
                      )
                    }}
                  >
                    <DButton
                      class="not-going-button"
                      @icon="times"
                      @label="discourse_post_event.models.invitee.status.not_going"
                      @action={{fn
                        this.changeWatchingInviteeStatus
                        "not_going"
                      }}
                    />
                  </PluginOutlet>
                </dropdown.item>
              {{/unless}}
            {{/if}}
          </DropdownMenu>
        </:content>
      </DMenu>
    </div>
  </template>
}
