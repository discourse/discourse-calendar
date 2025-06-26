import { i18n } from "discourse-i18n";

export function formatEventName(event) {
  let output = event.name || event.post.topic.title;

  if (event.showLocalTime && event.timezone) {
    output +=
      ` (${i18n("discourse_calendar.local_time")}: ` +
      moment(event.startsAt).tz(event.timezone).format("H:mma") +
      ")";
  }

  return output;
}
