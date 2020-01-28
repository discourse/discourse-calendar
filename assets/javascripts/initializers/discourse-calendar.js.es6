import { escapeExpression } from "discourse/lib/utilities";
import loadScript from "discourse/lib/load-script";
import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";
import { showPopover, hidePopover } from "discourse/lib/d-popover";

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
  let _topicController;

  api.decorateCooked(attachCalendar, {
    onlyStream: true,
    id: "discourse-calendar"
  });

  api.registerCustomPostMessageCallback("calendar_change", topicController => {
    const stream = topicController.get("model.postStream");
    const post = stream.findLoadedPost(stream.get("firstPostId"));
    const $op = $(".topic-post article#post_1");
    const $calendar = $op.find(".calendar").first();

    if (post && $calendar.length > 0) {
      ajax(`/posts/${post.id}.json`).then(post => {
        loadScript(
          "/plugins/discourse-calendar/javascripts/fullcalendar-with-moment-timezone.min.js"
        ).then(() => render($calendar, post));
      });
    }
  });

  function render($calendar, post) {
    $calendar = $calendar.empty();

    const timezone = _getTimeZone($calendar, api.getCurrentUser());
    const calendar = _buildCalendar($calendar, timezone);
    const isStatic = $calendar.attr("data-calendar-type") === "static";

    if (isStatic) {
      calendar.render();
      _setStaticCalendarEvents(calendar, $calendar, post);
    } else {
      _setDynamicCalendarEvents(calendar, post);
      calendar.render();
      _setDynamicCalendarOptions(calendar, $calendar);
    }

    _setupTimezonePicker(calendar, timezone);
  }

  function attachCalendar($elem, helper) {
    const $calendar = $(".calendar", $elem);

    if ($calendar.length === 0) {
      return;
    }

    loadScript(
      "/plugins/discourse-calendar/javascripts/fullcalendar-with-moment-timezone.min.js"
    ).then(() => render($calendar, helper.getModel()));
  }

  function _buildCalendar($calendar, timeZone) {
    let $calendarTitle = document.querySelector(
      ".discourse-calendar-header > .discourse-calendar-title"
    );
    const defaultView = escapeExpression(
      $calendar.attr("data-calendar-default-view") || "month"
    );

    return new window.FullCalendar.Calendar($calendar[0], {
      timeZone,
      timeZoneImpl: "moment-timezone",
      nextDayThreshold: "06:00:00",
      displayEventEnd: true,
      height: 650,
      firstDay: 1,
      defaultView,
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
      },
      datesRender: info => {
        _insertAddToCalendarLinks(info);
        $calendarTitle.innerText = info.view.title;
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
      allDay: false
    };

    if (to) {
      if (hasTimeSpecified(to.dateTime)) {
        event.end = to.dateTime.toDate();
      } else {
        event.end = to.dateTime.add(1, "days").toDate();
        event.allDay = true;
      }
    } else {
      event.allDay = true;
      if (from.weeklyRecurring) {
        event.startTime = {
          hours: from.dateTime.hours(),
          minutes: from.dateTime.minutes(),
          seconds: from.dateTime.seconds()
        };
        event.daysOfWeek = [from.dateTime.isoWeekday()];
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

    calendar.setOption("eventClick", ({ event, jsEvent }) => {
      hidePopover(jsEvent);
      const { postNumber } = event.extendedProps;
      if (!postNumber) return;
      _topicController =
        _topicController || api.container.lookup("controller:topic");
      _topicController.send("jumpToPost", postNumber);
    });

    calendar.setOption("eventMouseEnter", ({ event, jsEvent }) => {
      const { htmlContent } = event.extendedProps;
      if (!htmlContent) return;
      showPopover(jsEvent, { htmlContent });
    });

    calendar.setOption("eventMouseLeave", ({ jsEvent }) => {
      hidePopover(jsEvent);
    });
  }

  function _buildEvent(detail) {
    const event = _buildEventObject(
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

    event.extendedProps = {};

    if (detail.post_number) {
      event.extendedProps.postNumber = detail.post_number;
    } else {
      event.classNames = ["holiday"];
    }

    return event;
  }

  function _addStandaloneEvent(calendar, post, detail) {
    const event = _buildEvent(detail);

    const holidayCalendarTopicId = parseInt(
      Discourse.SiteSettings.holiday_calendar_topic_id,
      10
    );

    const text = detail.message.split("\n").filter(e => e);
    if (
      text.length &&
      post.topic_id &&
      holidayCalendarTopicId !== post.topic_id
    ) {
      event.title = text[0];
      event.extendedProps.description = text.slice(1).join(" ");
    } else {
      event.title = detail.username;
      event.backgroundColor = stringToHexColor(detail.username);
    }

    let popupText = detail.message.substr(0, 50);
    if (detail.message.length > 50) {
      popupText = popupText + "...";
    }
    event.extendedProps.htmlContent = popupText;
    event.title = event.title.replace(/<img[^>]*>/g, "");
    calendar.addEvent(event);
  }

  function _addGroupedEvent(calendar, post, detail) {
    let peopleCount = 0;
    let htmlContent = "";
    let usernames = [];
    let localEventNames = [];

    Object.keys(detail.localEvents)
      .sort()
      .forEach(key => {
        const localEvent = detail.localEvents[key];
        htmlContent += `<b>${key}</b>: ${localEvent.usernames
          .sort()
          .join(", ")}<br>`;
        usernames = usernames.concat(localEvent.usernames);
        localEventNames.push(key);
      });

    const event = _buildEvent(detail);
    event.classNames = ["grouped-event"];

    if (usernames.length > 3) {
      event.title =
        `(${usernames.length}) ` + I18n.t("discourse_calendar.holiday");
    } else if (usernames.length === 1) {
      event.title = usernames[0];
    } else {
      event.title = `(${usernames.length}) ` + usernames.slice(0, 3).join(", ");
    }

    if (localEventNames.length > 1) {
      event.extendedProps.htmlContent = htmlContent;
    } else {
      if (usernames.length > 1) {
        event.extendedProps.htmlContent = htmlContent;
      } else {
        event.extendedProps.htmlContent = localEventNames[0];
      }
    }

    calendar.addEvent(event);
  }

  function _setDynamicCalendarEvents(calendar, post) {
    const groupedEvents = [];

    (post.calendar_details || []).forEach(detail => {
      switch (detail.type) {
        case "grouped":
          groupedEvents.push(detail);
          break;
        case "standalone":
          _addStandaloneEvent(calendar, post, detail);
          break;
      }
    });

    const formatedGroupedEvents = {};
    groupedEvents.forEach(groupedEvent => {
      const minDate = moment(groupedEvent.from)
        .utc()
        .startOf("day")
        .subtract(12, "hours")
        .toISOString();
      const maxdate = moment(groupedEvent.to || groupedEvent.from)
        .utc()
        .endOf("day")
        .add(12, "hours")
        .toISOString();

      const identifier = `${minDate}-${maxdate}`;
      formatedGroupedEvents[identifier] = formatedGroupedEvents[identifier] || {
        from: groupedEvent.from,
        to: groupedEvent.to,
        localEvents: {}
      };

      formatedGroupedEvents[identifier].localEvents[
        groupedEvent.name
      ] = formatedGroupedEvents[identifier].localEvents[groupedEvent.name] || {
        usernames: []
      };

      formatedGroupedEvents[identifier].localEvents[
        groupedEvent.name
      ].usernames.push.apply(
        formatedGroupedEvents[identifier].localEvents[groupedEvent.name]
          .usernames,
        groupedEvent.usernames
      );
    });

    Object.keys(formatedGroupedEvents).forEach(key => {
      const formatedGroupedEvent = formatedGroupedEvents[key];
      _addGroupedEvent(calendar, post, formatedGroupedEvent);
    });
  }

  function _getTimeZone($calendar, currentUser) {
    let defaultTimezone = $calendar.attr("data-calendar-default-timezone");
    const isValidDefaultTimezone = !!moment.tz.zone(defaultTimezone);
    if (!isValidDefaultTimezone) {
      defaultTimezone = null;
    }

    return (
      defaultTimezone ||
      (currentUser && currentUser.timezone) ||
      moment.tz.guess()
    );
  }

  function _setupTimezonePicker(calendar, timezone) {
    let $timezonePicker = $(".discourse-calendar-timezone-picker");

    if ($timezonePicker.length) {
      $timezonePicker.on("change", function(event) {
        calendar.setOption("timeZone", event.target.value);
        _insertAddToCalendarLinks(calendar);
      });

      moment.tz.names().forEach(timezone => {
        $timezonePicker.append(new Option(timezone, timezone));
      });

      $timezonePicker.val(timezone);
    } else {
      $(".discourse-calendar-timezone-wrap").text(timezone);
    }
  }

  function _insertAddToCalendarLinks(info) {
    if (info.view.type !== "listNextYear") return;

    const eventSegments = info.view.eventRenderer.segs;
    const eventSegmentDefMap = _eventSegmentDefMap(info);

    for (const event of eventSegments) {
      _insertAddToCalendarLinkForEvent(event, eventSegmentDefMap);
    }
  }

  function _insertAddToCalendarLinkForEvent(event, eventSegmentDefMap) {
    const eventTitle = event.eventRange.def.title;
    let map = eventSegmentDefMap[event.eventRange.def.defId];
    let startDate = map.start;
    let endDate = map.end;

    endDate = endDate
      ? _formatDateForGoogleApi(endDate, event.eventRange.def.allDay)
      : _endDateForAllDayEvent(startDate, event.eventRange.def.allDay);
    startDate = _formatDateForGoogleApi(startDate, event.eventRange.def.allDay);

    const link = document.createElement("a");
    const title = I18n.t("discourse_calendar.add_to_calendar");
    link.title = title;
    link.appendChild(document.createTextNode(title));
    link.href = `
      http://www.google.com/calendar/event?action=TEMPLATE&text=${encodeURIComponent(
        eventTitle
      )}&dates=${startDate}/${endDate}&details=${encodeURIComponent(
      event.eventRange.def.extendedProps.description
    )}`;
    link.target = "_blank";
    link.classList.add("fc-list-item-add-to-calendar");
    event.el.querySelector(".fc-list-item-title").appendChild(link);
  }

  function _formatDateForGoogleApi(date, allDay = false) {
    if (!allDay) return date.toISOString().replace(/-|:|\.\d\d\d/g, "");

    return moment(date)
      .utc()
      .format("YYYYMMDD");
  }

  function _endDateForAllDayEvent(startDate, allDay) {
    const unit = allDay ? "days" : "hours";
    return _formatDateForGoogleApi(
      moment(startDate)
        .add(1, unit)
        .toDate(),
      allDay
    );
  }

  function _eventSegmentDefMap(info) {
    let map = {};

    for (let event of info.view.calendar.getEvents()) {
      map[event._instance.defId] = { start: event.start, end: event.end };
    }
    return map;
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
