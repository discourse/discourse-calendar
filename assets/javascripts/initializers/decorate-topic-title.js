import { withPluginApi } from "discourse/lib/plugin-api";
import eventRelativeDate from "discourse/plugins/discourse-calendar/lib/event-relative-date";

function initializeDecorateTopicTitle(api) {
  api.decorateTopicTitle((topic, node, topicTitleType) => {
    const container = node.querySelector(".event-date-container");
    container && container.remove();

    if (!topic.event_starts_at || !topic.event_ends_at) {
      return;
    }

    if (
      topicTitleType === "topic-list-item-title" ||
      topicTitleType === "header-title"
    ) {
      const eventdateContainer = document.createElement("div");
      eventdateContainer.classList.add("event-date-container");

      const eventDate = document.createElement("span");
      eventDate.classList.add("event-date", "event-relative-date");
      eventDate.dataset.starts_at = topic.event_starts_at;
      eventDate.dataset.ends_at = topic.event_ends_at;

      eventdateContainer.appendChild(eventDate);
      node.appendChild(eventdateContainer);

      // we force a first computation, as waiting for the auto update might take time
      eventRelativeDate(eventDate);
    }
  });
}

export default {
  name: "decorate-topic-title",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (siteSettings.discourse_post_event_enabled) {
      withPluginApi("0.8.40", initializeDecorateTopicTitle);
    }
  },
};
