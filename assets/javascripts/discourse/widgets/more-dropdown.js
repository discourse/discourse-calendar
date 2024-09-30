import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import I18n from "I18n";

export default createWidget("more-dropdown", {
  tagName: "div.more-dropdown",

  buildKey: () => "more-dropdown",

  transform(attrs) {
    return {
      content: this._buildContent(attrs),
      onChange: (item) => this.sendWidgetAction(item.id, item.param),
      options: {},
    };
  },

  template: hbs`
    {{attach
      widget="widget-dropdown"
      attrs=(hash
        id="more-dropdown"
        translatedLabel="More"
        icon="ellipsis-h"
        content=this.transformed.content
        onChange=this.transformed.onChange
        options=this.transformed.options
      )
    }}
  `,

  buildClasses(attrs) {
    const content = this._buildContent(attrs);
    if (!content.length) {
      return ["has-no-actions"];
    }
  },

  _buildContent({ canActOnEvent, isPublicEvent, eventModel }) {
    const content = [];
    const expiredOrClosed = eventModel.is_expired || eventModel.is_closed;

    if (!expiredOrClosed) {
      content.push({
        id: "addToCalendar",
        icon: "file",
        label:
          "discourse_calendar.discourse_post_event.event_ui.add_to_calendar",
      });
    }

    if (this.currentUser) {
      content.push({
        id: "sendPMToCreator",
        icon: "envelope",
        translatedLabel: I18n.t(
          "discourse_calendar.discourse_post_event.event_ui.send_pm_to_creator",
          { username: eventModel.creator.username }
        ),
      });
    }

    if (!expiredOrClosed && canActOnEvent && isPublicEvent) {
      content.push({
        id: "inviteUserOrGroup",
        icon: "user-plus",
        label: "discourse_calendar.discourse_post_event.event_ui.invite",
        param: eventModel.id,
      });
    }

    if (eventModel.watching_invitee && isPublicEvent) {
      content.push({
        id: "leaveEvent",
        icon: "times",
        label: "discourse_calendar.discourse_post_event.event_ui.leave",
        param: eventModel.id,
      });
    }

    if (!eventModel.is_closed && eventModel.recurrence) {
      content.push({
        id: "upcomingEvents",
        icon: "far-calendar-plus",
        label: "discourse_post_event.event_ui.upcoming_events",
      });
    }

    if (canActOnEvent) {
      content.push("separator");

      content.push({
        icon: "file-csv",
        id: "exportPostEvent",
        label: "discourse_calendar.discourse_post_event.event_ui.export_event",
        param: eventModel.id,
      });

      if (!expiredOrClosed && !eventModel.is_standalone) {
        content.push({
          icon: "file-upload",
          id: "bulkInvite",
          label: "discourse_calendar.discourse_post_event.event_ui.bulk_invite",
          param: eventModel,
        });
      }

      if (eventModel.is_closed) {
        content.push({
          icon: "unlock",
          id: "openEvent",
          label: "discourse_calendar.discourse_post_event.event_ui.open_event",
          param: eventModel,
        });
      } else {
        content.push({
          icon: "pencil-alt",
          id: "editPostEvent",
          label: "discourse_calendar.discourse_post_event.event_ui.edit_event",
          param: eventModel.id,
        });

        if (!eventModel.is_expired) {
          content.push({
            icon: "times",
            id: "closeEvent",
            label:
              "discourse_calendar.discourse_post_event.event_ui.close_event",
            class: "danger",
            param: eventModel,
          });
        }
      }
    }

    return content;
  },
});
