import { h } from "virtual-dom";
import RawHtml from "discourse/widgets/raw-html";
import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import I18n from "I18n";

export default createWidget("discourse-post-event-dates", {
  tagName: "section.event-dates",

  showAllParticipatingInvitees(postId) {
    this.sendWidgetAction("showAllInvitees", {
      postId,
      title: "title_participated",
      extraClass: "participated",
    });
  },

  html({ localDates, eventModel }) {
    const content = [
      iconNode("clock"),
      h("span.date", new RawHtml({ html: `<span>${localDates}</span>` })),
    ];

    if (
      eventModel.is_expired &&
      !eventModel.is_closed &&
      !eventModel.is_standalone
    ) {
      let participants;
      const label = I18n.t(
        "discourse_calendar.discourse_post_event.event_ui.participants",
        {
          count: eventModel.stats.going,
        }
      );
      if (eventModel.stats.going > 0) {
        participants = this.attach("link", {
          action: "showAllParticipatingInvitees",
          actionParam: eventModel.id,
          contents: () => label,
        });
      } else {
        participants = label;
      }

      content.push(h("span.participants", [h("span", " - "), participants]));
    }

    return content;
  },
});
