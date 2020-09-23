import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";
import guessDateFormat from "discourse/plugins/discourse-calendar/lib/guess-best-date-format";

function initializeDecorateTopicTitle(api) {
  api.decorateTopicTitle((topic, node, topicTitleType) => {
    const startsAt = topic.event_starts_at;

    if (startsAt) {
      const date = moment.utc(startsAt);

      if (topicTitleType === "topic-list-item-title") {
        if (node.querySelector(".event-date-container")) {
          return;
        }

        const formattedDate = date
          .tz(moment.tz.guess())
          .format(guessDateFormat(date));
        if (moment().isBefore(date)) {
          node.title = I18n.t("discourse_post_event.topic_title.starts_at", {
            date: formattedDate,
          });
        } else {
          node.title = I18n.t("discourse_post_event.topic_title.ended_at", {
            date: formattedDate,
          });
        }

        const eventdateContainer = document.createElement("div");
        eventdateContainer.classList.add("event-date-container");

        const eventDate = document.createElement("span");
        eventDate.classList.add("event-date", "relative-future-date");
        eventDate.dataset.time = date.tz(moment.tz.guess()).valueOf();

        eventDate.innerText = date.tz(moment.tz.guess()).from(moment());

        eventdateContainer.appendChild(eventDate);
        node.appendChild(eventdateContainer);
      }

      if (topicTitleType === "header-title") {
        if (node.querySelector(".event-date")) {
          return;
        }

        const child = document.createElement("span");
        child.classList.add("event-date");
        child.innerText = date
          .tz(moment.tz.guess())
          .format(guessDateFormat(date));
        node.appendChild(child);
      }
    }
  });
}

export default {
  name: "decorate-topic-title",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.discourse_post_event_enabled) {
      withPluginApi("0.8.40", initializeDecorateTopicTitle);
    }
  },
};
