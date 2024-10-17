import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";

export default class DiscoursePostEventStatus extends Component {
  @service appEvents;
  @service discoursePostEventApi;
  @service store;

  get watchingInviteeStatus() {
    return this.args.event.watchingInvitee?.status;
  }

  @action
  async changeWatchingInviteeStatus(status) {
    if (this.args.event.watchingInvitee) {
      const currentStatus = this.args.event.watchingInvitee.status;
      let newStatus = status;
      if (status === currentStatus && status === "interested") {
        newStatus = null;
      }

      await this.discoursePostEventApi.updateEventAttendance(this.args.event, {
        status: newStatus,
      });

      this.appEvents.trigger("calendar:update-invitee-status", {
        status: newStatus,
        postId: this.args.event.id,
      });
    } else {
      await this.discoursePostEventApi.joinEvent(this.args.event, { status });

      this.appEvents.trigger("calendar:create-invitee-status", {
        status,
        postId: this.args.event.id,
      });
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
      {{#unless @event.minimal}}
        <PluginOutlet
          @name="discourse-post-event-going-button"
          @outletArgs={{hash
            event=@event
            changeWatchingInviteeStatus=this.changeWatchingInviteeStatus
          }}
        >
          <DButton
            class="going-button"
            @icon="check"
            @label="discourse_calendar.discourse_post_event.models.invitee.status.going"
            @action={{fn this.changeWatchingInviteeStatus "going"}}
          />
        </PluginOutlet>
      {{/unless}}

      <PluginOutlet
        @name="discourse-post-event-interested-button"
        @outletArgs={{hash
          event=@event
          changeWatchingInviteeStatus=this.changeWatchingInviteeStatus
        }}
      >
        <DButton
          class="interested-button"
          @icon="star"
          @label="discourse_calendar.discourse_post_event.models.invitee.status.interested"
          @action={{fn this.changeWatchingInviteeStatus "interested"}}
        />
      </PluginOutlet>

      {{#unless @event.minimal}}
        <PluginOutlet
          @name="discourse-post-event-not-going-button"
          @outletArgs={{hash
            event=@event
            changeWatchingInviteeStatus=this.changeWatchingInviteeStatus
          }}
        >
          <DButton
            class="not-going-button"
            @icon="times"
            @label="discourse_calendar.discourse_post_event.models.invitee.status.not_going"
            @action={{fn this.changeWatchingInviteeStatus "not_going"}}
          />
        </PluginOutlet>
      {{/unless}}
    </div>
  </template>
}
