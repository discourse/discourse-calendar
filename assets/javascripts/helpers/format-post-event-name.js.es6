import { htmlHelper } from "discourse-common/lib/helpers";

export default htmlHelper(postEvent => {
  return postEvent.name || postEvent.post.topic.title;
});
