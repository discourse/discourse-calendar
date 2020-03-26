import { htmlHelper } from "discourse-common/lib/helpers";

export default htmlHelper(postEvent => {
  return moment(postEvent.starts_at).format("LLL");
});
