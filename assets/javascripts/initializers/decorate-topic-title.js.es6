import { withPluginApi } from "discourse/lib/plugin-api";
import guessDateFormat from "discourse/plugins/discourse-calendar/lib/guess-best-date-format";

function initializeDecorateTopicTitle(api) {
  api.decorateTopicTitle((topic, node, topicTitleType) => {
    const startsAt = topic.event_starts_at;
    if (startsAt) {
      if (topicTitleType === "topic-list-item-title") {
        if (node.querySelector(".event-date")) {
          return;
        }

        const date = moment.utc(startsAt);
        const dateContainer = document.createElement("span");
        dateContainer.classList.add("event-date");
        dateContainer.innerText = date
          .tz(moment.tz.guess())
          .format(guessDateFormat(date));

        node.appendChild(dateContainer);
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
  }
};
