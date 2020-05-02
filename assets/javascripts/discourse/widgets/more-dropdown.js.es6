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

  _buildContent(attrs) {
    const content = [];

    if (!attrs.isExpired) {
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
          { username: attrs.creatorUsername }
        )
      });
    }

    if (!attrs.isExpired && attrs.canActOnEvent && attrs.isPublicEvent) {
      content.push({
        id: "inviteUserOrGroup",
        icon: "user-plus",
        label: "discourse_post_event.event_ui.invite",
        param: attrs.postEventId
      });
    }

    if (attrs.canActOnEvent) {
      content.push("separator");

      content.push({
        icon: "file-csv",
        id: "exportPostEvent",
        label: "discourse_post_event.event_ui.export_event",
        param: attrs.postEventId
      });

      content.push({
        icon: "pencil-alt",
        id: "editPostEvent",
        label: "discourse_post_event.event_ui.edit_event",
        param: attrs.postEventId
      });
    }
    return content;
  }
});
