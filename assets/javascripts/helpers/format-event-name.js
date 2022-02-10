import { htmlHelper } from "discourse-common/lib/helpers";

export function formatEventName(event) {
  return event.name || event.post.topic.title;
}

export default htmlHelper((event) => formatEventName(event));
