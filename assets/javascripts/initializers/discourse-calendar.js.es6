import loadScript from "discourse/lib/load-script";
import { withPluginApi } from "discourse/lib/plugin-api";
import { minimumOffset } from "discourse/lib/offset-calculator";
import { ajax } from "discourse/lib/ajax";

// https://stackoverflow.com/a/16348977
/* eslint-disable */
// prettier-ignore
function stringToHexColor(str) {
  var hash = 0;
  for (var i = 0; i < str.length; i++) {
    hash = str.charCodeAt(i) + ((hash << 5) - hash);
  }
  var hex = "#";
  for (var i = 0; i < 3; i++) {
    var value = (hash >> (i * 8)) & 0xff;
    hex += ("00" + value.toString(16)).substr(-2);
  }
  return hex;
}

function initializeDiscourseCalendar(api) {
  api.decorateCooked(attachCalendar, { onlyStream: true });

  function calendarChanged(topicsController) {
    const stream = topicsController.get("model.postStream");
    const post = stream.findLoadedPost(stream.get("firstPostId"));
    const $op = $(".topic-post article#post_1");
    const $calendar = $op.find(".calendar").first();

    if (post && $calendar.length > 0) {
      ajax(`/posts/${post.id}.json`).then(data => {
        render($calendar, data, true);
      });
    }
  }
  api.registerCustomPostMessageCallback("calendar_change", calendarChanged);

  function render($calendar, post, force = false) {
    if (!force && $calendar.hasClass("fc")) {
      return;
    }

    $calendar = $calendar
      .empty()
      .html(
        '<div class="calendar" data-calendar-type="' +
          $calendar.attr("data-calendar-type") +
          '"></div>'
      );

    const calendar = _buildCalendar($calendar);

    const isStatic = $calendar.attr("data-calendar-type") === "static";

    if (isStatic) {
      calendar.render();
      _setStaticCalendarEvents(calendar, $calendar, post);
    } else {
      _setDynamicCalendarEvents(calendar, post);
      calendar.render();
      _setDynamicCalendarOptions(calendar, $calendar);
    }
  }

  function attachCalendar($elem, helper) {
    const $calendar = $(".calendar", $elem);

    if ($calendar.length === 0) {
      return;
    }

    loadScript(
      "/plugins/discourse-calendar/javascripts/fullcalendar.min.js"
    ).then(() => render($calendar, helper.getModel()));
  }

  function _buildCalendar($calendar) {
    return new window.FullCalendar.Calendar($calendar[0], {
      timeZone: moment.tz.guess(),
      timeZoneImpl: "moment-timezone",
      nextDayThreshold: "23:59:59",
      displayEventEnd: true,
      height: 700,
      firstDay: 1,
      views: {
        listNextYear: {
          type: "list",
          duration: { days: 365 },
          buttonText: "list",
          listDayFormat: {
            month: "long",
            year: "numeric",
            day: "numeric",
            weekday: "long"
          }
        }
      },
      header: {
        left: "prev,next today",
        center: "title",
        right: "month,basicWeek,listNextYear"
      }
    });
  }

  function _convertHtmlToDate(html) {
    const date = html.attr("data-date");

    if (!date) {
      return null;
    }

    const time = html.attr("data-time");
    const timezone = html.attr("data-timezone");
    let dateTime = date;
    if (time) {
      dateTime = `${dateTime} ${time}`;
    }

    return {
      weeklyRecurring: html.attr("data-recurring") === "1.weeks",
      dateTime: moment.tz(dateTime, timezone || "Etc/UTC")
    };
  }

  function _buildEventObject(from, to) {
    const hasTimeSpecified = d => {
      return d.hours() !== 0 || d.minutes() !== 0 || d.seconds() !== 0;
    };

    let event = {
      start: from.dateTime.toDate(),
      allDay: true
    };

    if (from && !to) {
      if (hasTimeSpecified(from.dateTime)) {
        event.allDay = false;
      }

      if (from.weeklyRecurring) {
        event.startTime = {
          hours: from.dateTime.hours(),
          minutes: from.dateTime.minutes(),
          seconds: from.dateTime.seconds()
        };

        event.daysOfWeek = [from.dateTime.isoWeekday()];
      }
    }

    if (from && to) {
      if (hasTimeSpecified(from.dateTime) && hasTimeSpecified(to.dateTime)) {
        event.end = to.dateTime.toDate();
        event.allDay = false;
      } else {
        event.end = to.dateTime.add(1, "days").toDate();
      }
    }

    return event;
  }

  function _setStaticCalendarEvents(calendar, $calendar, post) {
    $(`<div>${post.cooked}</div>`)
      .find('.calendar[data-calendar-type="static"] p')
      .html()
      .trim()
      .split("<br>")
      .forEach(line => {
        const html = $.parseHTML(line);
        const htmlDates = html.filter(h =>
          $(h).hasClass("discourse-local-date")
        );

        const from = _convertHtmlToDate($(htmlDates[0]));
        const to = _convertHtmlToDate($(htmlDates[1]));

        let event = _buildEventObject(from, to);
        event.title = html[0].textContent.trim();
        calendar.addEvent(event);
      });
  }

  function _setDynamicCalendarOptions(calendar, $calendar) {
    const skipWeekends = $calendar.attr("data-weekends") === "false";
    const hiddenDays = $calendar.attr("data-hidden-days");

    if (skipWeekends) {
      calendar.setOption("weekends", false);
    }

    if (hiddenDays) {
      calendar.setOption(
        "hiddenDays",
        hiddenDays.split(",").map(d => parseInt(d))
      );
    }

    calendar.setOption("eventClick", calEvent => {
      const postNumber = calEvent.event.extendedProps.postNumber;
      const $post = $(`.topic-post article#post_${postNumber}`);
      $(window).scrollTop($post.offset().top - minimumOffset());
    });
  }

  function _setDynamicCalendarEvents(calendar, post) {
    post.calendar_details.forEach(detail => {
      let event = _buildEventObject(
        detail.from
          ? {
              dateTime: moment(detail.from),
              weeklyRecurring: detail.recurring === "1.weeks"
            }
          : null,
        detail.to
          ? {
              dateTime: moment(detail.to),
              weeklyRecurring: detail.recurring === "1.weeks"
            }
          : null
      );

      const excerpt = detail.message.split("\n").filter(e => e);

      if (excerpt.length) {
        event.title = excerpt[0];
      } else {
        event.title = detail.username;
      }

      event.backgroundColor = stringToHexColor(detail.username);
      event.extendedProps = {
        postNumber: parseInt(detail.post_number, 10)
      };

      calendar.addEvent(event);
    });
  }
}

export default {
  name: "discourse-calendar",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.calendar_enabled) {
      withPluginApi("0.8.22", initializeDiscourseCalendar);
    }
  }
};
