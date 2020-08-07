import { createWidget } from "discourse/widgets/widget";
import hbs from "discourse/widgets/hbs-compiler";

export default createWidget("more-dropdown", {
  tagName: "div.more-dropdown",

  buildKey: () => "more-dropdown",

  transform(attrs) {
    return {
      content: this._buildContent(attrs),
      onChange: item => this.sendWidgetAction(item.id, item.param),
      options: {}
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

  _buildContent(attrs) {
    const content = [];

    if (!attrs.eventModel.is_expired) {
      content.push({
        id: "addToCalendar",
        icon: "file",
        label: "discourse_post_event.event_ui.add_to_calendar"
      });
    }

    if (this.currentUser) {
      content.push({
        id: "sendPMToCreator",
        icon: "envelope",
        translatedLabel: I18n.t(
          "discourse_post_event.event_ui.send_pm_to_creator",
          { username: attrs.eventModel.creator.username }
        )
      });
    }

    if (!attrs.is_expired && attrs.canActOnEvent && attrs.isPublicEvent) {
      content.push({
        id: "inviteUserOrGroup",
        icon: "user-plus",
        label: "discourse_post_event.event_ui.invite",
        param: attrs.eventModel.id
      });
    }

    if (attrs.canActOnEvent) {
      content.push("separator");

      content.push({
        icon: "file-csv",
        id: "exportPostEvent",
        label: "discourse_post_event.event_ui.export_event",
        param: attrs.eventModel.id
      });

      content.push({
        icon: "file-upload",
        id: "bulkInvite",
        label: "discourse_post_event.event_ui.bulk_invite",
        param: attrs.eventModel.id
      });

      content.push({
        icon: "pencil-alt",
        id: "editPostEvent",
        label: "discourse_post_event.event_ui.edit_event",
        param: attrs.eventModel.id
      });

      if (!attrs.eventModel.is_expired) {
        content.push({
          icon: "times",
          id: "closePostEvent",
          label: "discourse_post_event.event_ui.close_event",
          class: "danger",
          param: attrs.eventModel
        });
      }
    }

    return content;
  }
});
