import { withPluginApi } from "discourse/lib/plugin-api";
import guessDateFormat from "discourse/plugins/discourse-calendar/lib/guess-best-date-format";
import cleanTitle from "discourse/plugins/discourse-calendar/lib/clean-title";

function initializeDecorateTopicTitle(api) {
  api.decorateTopicTitle((topic, node, topicTitleType) => {
    const startsAt = topic.post_event_starts_at;
    if (startsAt) {
      const cleanedTitle = cleanTitle(node.innerText, startsAt);

      if (cleanedTitle) {
        if (topicTitleType === "topic-list-item-title") {
          const date = moment.utc(startsAt);
          node.innerHTML = `${node.innerText.replace(
            cleanedTitle,
            ""
          )}<span class="post-event-date">${date
            .tz(moment.tz.guess())
            .format(guessDateFormat(date))}</span>`;
        } else if (topicTitleType === "topic-title") {
          node.innerText = node.innerText.replace(cleanedTitle, "");
        }
      }
    }
  });
}

export default {
  name: "decorate-topic-title",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.post_event_enabled) {
      withPluginApi("0.8.40", initializeDecorateTopicTitle);
    }
  }
};
