import { htmlHelper } from "discourse-common/lib/helpers";

export default htmlHelper(event => {
  return event.name || event.post.topic.title;
});
