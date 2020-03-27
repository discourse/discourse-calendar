import guessDateFormat from "discourse/plugins/discourse-calendar/lib/guess-best-date-format";
import { htmlHelper } from "discourse-common/lib/helpers";

export default htmlHelper(date => {
  date = moment.utc(date).tz(moment.tz.guess());
  const format = guessDateFormat(date);
  return date.format(format);
});
