import {
  getCalendarButtonsText,
  getCurrentBcp47Locale,
} from "../lib/calendar-locale";
import { buildPopover, destroyPopover } from "../lib/popover";

export default function fullCalendarDefaultOptions() {
  return {
    eventClick: function () {
      destroyPopover();
    },
    locale: getCurrentBcp47Locale(),
    buttonText: getCalendarButtonsText(),
    eventMouseEnter: function ({ event, jsEvent }) {
      destroyPopover();
      const htmlContent = event.title;
      buildPopover(jsEvent, htmlContent);
    },
    eventMouseLeave: function () {
      destroyPopover();
    },
  };
}
