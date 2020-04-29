import { createWidget } from "discourse/widgets/widget";
import hbs from "discourse/widgets/hbs-compiler";

export default createWidget("discourse-post-event-status", {
  tagName: "div.event-status",

  buildKey: attrs => `discourse-post-event-status-${attrs.id}`,

  buildClasses(attrs) {
    if (attrs.watchingInvitee) {
      return `status-${attrs.watchingInvitee.status}`;
    }
  },

  defaultState(attrs) {
    const status = attrs.watchingInvitee ? attrs.watchingInvitee.status : null;

    return {
      onChange: data => {
        this.state.icon = null;
        this.state.label = data.label;
        this.state.options.headerClass = "disabled";
        this.sendWidgetAction("changeWatchingInviteeStatus", data.id);
      },
      icon: this._headerIconForStatus(status),
      options: {
        caret: true,
        headerClass: ""
      },
      label: status
        ? `discourse_post_event.models.invitee.status.${status}`
        : "discourse_post_event.models.invitee.status.unknown",
      statuses: this._statusesForStatus(status)
    };
  },

  transform(attrs) {
    return {
      mightAttend:
        attrs.status &&
        (attrs.watchingInvitee.status === "going" ||
          attrs.watchingInvitee.status === "interested")
    };
  },

  template: hbs`
    {{#if transformed.mightAttend}}
      {{attach
        widget="widget-dropdown"
        attrs=(hash
          id="discourse-post-event-status-dropdown"
          label=state.label
          icon=state.icon
          content=state.statuses
          onChange=state.onChange
          options=state.options
        )
      }}
    {{else}}
      {{attach widget="interested-button"}}
      {{attach widget="going-button"}}
    {{/if}}
  `,

  _statusesForStatus(status) {
    switch (status) {
      case "going":
        return [
          {
            id: "going",
            label: "discourse_post_event.models.invitee.status.going"
          },
          {
            id: "interested",
            label: "discourse_post_event.models.invitee.status.interested"
          },
          "separator",
          {
            id: "not_going",
            label: "discourse_post_event.models.invitee.status.not_going"
          }
        ];
      case "interested":
        return [
          {
            id: "going",
            label: "discourse_post_event.models.invitee.status.going"
          },
          {
            id: "interested",
            label: "discourse_post_event.models.invitee.status.interested"
          },
          "separator",
          {
            id: "not_going",
            label: "discourse_post_event.models.invitee.status.not_going"
          }
        ];
      case "not_going":
        return [
          {
            id: "going",
            label: "discourse_post_event.models.invitee.status.going"
          },
          {
            id: "not_going",
            label: "discourse_post_event.models.invitee.status.not_going"
          },
          "separator",
          {
            id: "interested",
            label: "discourse_post_event.models.invitee.status.interested"
          }
        ];
    }
  },

  _headerIconForStatus(status) {
    switch (status) {
      case "going":
        return "check";
      case "interested":
        return "star";
      case "not_going":
        return "times";
    }
  }
});
