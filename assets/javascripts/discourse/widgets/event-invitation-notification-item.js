import I18n from "I18n";
import { createWidgetFrom } from "discourse/widgets/widget";
import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import { escapeExpression, formatUsername } from "discourse/lib/utilities";
import { iconNode } from "discourse-common/lib/icon-library";

createWidgetFrom(
  DefaultNotificationItem,
  "event-invitation-notification-item",
  {
    notificationTitle(notificationName, data) {
      return data.title ? I18n.t(data.title) : "";
    },

    text(notificationName, data) {
      const username = `<span>${formatUsername(data.display_username)}</span>`;
      let description;
      if (data.topic_title) {
        description = `<span data-topic-id="${
          this.attrs.topic_id
        }">${escapeExpression(data.topic_title)}</span>`;
      } else {
        description = this.description(data);
      }

      return I18n.t(data.message, { description, username });
    },

    icon(notificationName, data) {
      return iconNode(`notification.${data.message}`);
    },
  }
);
