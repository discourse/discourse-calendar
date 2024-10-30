export function formatEventName(event) {
  return event.name || event.post.topic.title;
}
