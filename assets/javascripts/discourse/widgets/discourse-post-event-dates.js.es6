import RawHtml from "discourse/widgets/raw-html";
import { iconNode } from "discourse-common/lib/icon-library";
import { h } from "virtual-dom";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("discourse-post-event-dates", {
  tagName: "section.event-dates",

  showAllParticipatingInvitees(postId) {
    this.sendWidgetAction("showAllInvitees", {
      postId,
      title: "title_participated",
      extraClass: "participated"
    });
  },

  html(attrs) {
    const content = [
      iconNode("clock"),
      h("span.date", new RawHtml({ html: attrs.localDates }))
    ];

    if (
      attrs.eventModel.is_expired &&
      attrs.eventModel.status !== "standalone"
    ) {
      let participants;
      const label = I18n.t("event.post_ui.participants", {
        count: attrs.eventModel.stats.going
      });
      if (attrs.eventModel.stats.going > 0) {
        participants = this.attach("link", {
          action: "showAllParticipatingInvitees",
          actionParam: attrs.eventModel.id,
          contents: () => label
        });
      } else {
        participants = label;
      }

      content.push(h("span.participants", [h("span", " - "), participants]));
    }

    return content;
  }
});
