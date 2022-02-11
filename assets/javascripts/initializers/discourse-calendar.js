import { Promise } from "rsvp";
import { isPresent } from "@ember/utils";
import DiscourseURL from "discourse/lib/url";
import { cookAsync } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import loadScript from "discourse/lib/load-script";
import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";
import { hidePopover, showPopover } from "discourse/lib/d-popover";
import Category from "discourse/models/category";
import I18n from "I18n";
import {
  colorToHex,
  contrastColor,
  stringToColor,
} from "discourse/plugins/discourse-calendar/lib/colors";

function loadFullCalendar() {
  return loadScript(
    "/plugins/discourse-calendar/javascripts/fullcalendar-with-moment-timezone.min.js"
  );
}

function initializeDiscourseCalendar(api) {
  let _topicController;
  const siteSettings = api.container.lookup("site-settings:main");
  const outletName = siteSettings.calendar_categories_outlet;

  const site = api.container.lookup("site:main");
  const isMobileView = site && site.mobileView;

  let selector = `.${outletName}-outlet`;
  if (outletName === "before-topic-list-body") {
    selector = `.topic-list:not(.shared-drafts) .${outletName}-outlet`;
  }

  api.onPageChange((url) => {
    const $calendarContainer = $(`${selector}.category-calendar`);
    if (!$calendarContainer.length) {
      return;
    }

    $calendarContainer.hide();

    const browsedCategory = Category.findBySlugPathWithID(url);
    if (browsedCategory) {
      const settings = siteSettings.calendar_categories
        .split("|")
        .filter(Boolean)
        .map((stringSetting) => {
          const data = {};
          stringSetting
            .split(";")
            .filter(Boolean)
            .forEach((s) => {
              const parts = s.split("=");
              data[parts[0]] = parts[1];
            });
          return data;
        });

      const categorySetting = settings.findBy(
        "categoryId",
        browsedCategory.id.toString()
      );

      if (categorySetting && categorySetting.postId) {
        $calendarContainer.show();
        const postId = categorySetting.postId;
        const $spinner = $(
          '<div class="calendar"><div class="spinner medium"></div></div>'
        );
        $calendarContainer.html($spinner);
        loadFullCalendar().then(() => {
          const options = [`postId=${postId}`];

          const optionals = ["weekends", "tzPicker", "defaultView"];
          optionals.forEach((optional) => {
            if (isPresent(categorySetting[optional])) {
              options.push(
                `${optional}=${escapeExpression(categorySetting[optional])}`
              );
            }
          });

          const rawCalendar = `[calendar ${options.join(" ")}]\n[/calendar]`;
          const cookRaw = cookAsync(rawCalendar);
          const loadPost = ajax(`/posts/${postId}.json`);
          Promise.all([cookRaw, loadPost]).then((results) => {
            const cooked = results[0];
            const post = results[1];
            const $cooked = $(cooked.string);
            $calendarContainer.html($cooked);
            render($(".calendar", $cooked), post);
          });
        });
      }
    }
  });

  api.decorateCooked(($elem, helper) => attachCalendar($elem, helper), {
    onlyStream: true,
    id: "discourse-calendar",
  });

  api.cleanupStream(cleanUp);

  api.registerCustomPostMessageCallback(
    "calendar_change",
    (topicController) => {
      const stream = topicController.get("model.postStream");
      const post = stream.findLoadedPost(stream.get("firstPostId"));
      const $op = $(".topic-post article#post_1");
      const $calendar = $op.find(".calendar").first();

      if (post && $calendar.length > 0) {
        ajax(`/posts/${post.id}.json`).then(() =>
          loadFullCalendar().then(() => render($calendar, post))
        );
      }
    }
  );

  function render($calendar, post) {
    $calendar = $calendar.empty();

    const timezone = _getTimeZone($calendar, api.getCurrentUser());
    const calendar = _buildCalendar($calendar, timezone);
    const isStatic = $calendar.attr("data-calendar-type") === "static";
    const fullDay = $calendar.attr("data-calendar-full-day") === "true";

    if (isStatic) {
      calendar.render();
      _setStaticCalendarEvents(calendar, $calendar, post);
    } else {
      _setDynamicCalendarEvents(calendar, post, fullDay);
      calendar.render();
      _setDynamicCalendarOptions(calendar, $calendar);
    }

    _setupTimezonePicker(calendar, timezone);
  }

  function cleanUp() {
    window.removeEventListener("scroll", hidePopover);
  }

  function attachCalendar($elem, helper) {
    window.addEventListener("scroll", hidePopover);

    const $calendar = $(".calendar", $elem);

    if ($calendar.length === 0) {
      return;
    }

    loadFullCalendar().then(() => render($calendar, helper.getModel()));
  }

  function _buildCalendar($calendar, timeZone) {
    let $calendarTitle = document.querySelector(
      ".discourse-calendar-header > .discourse-calendar-title"
    );

    const defaultView = escapeExpression(
      $calendar.attr("data-calendar-default-view") ||
        (isMobileView ? "listNextYear" : "month")
    );

    const showAddToCalendar =
      $calendar.attr("data-calendar-show-add-to-calendar") !== "false";

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
            weekday: "long",
          },
        },
      },
      header: {
        left: "prev,next today",
        center: "title",
        right: "month,basicWeek,listNextYear",
      },
      datesRender: (info) => {
        if (showAddToCalendar) {
          _insertAddToCalendarLinks(info);
        }

        $calendarTitle.innerText = info.view.title;
      },
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
      dateTime: moment.tz(dateTime, timezone || "Etc/UTC"),
    };
  }

  function _buildEventObject(from, to) {
    const hasTimeSpecified = (d) => {
      return d.hours() !== 0 || d.minutes() !== 0 || d.seconds() !== 0;
    };

    let event = {
      start: from.dateTime.toDate(),
      allDay: false,
    };

    if (to) {
      if (hasTimeSpecified(to.dateTime) || hasTimeSpecified(from.dateTime)) {
        event.end = to.dateTime.toDate();
      } else {
        event.end = to.dateTime.add(1, "days").toDate();
        event.allDay = true;
      }
    } else {
      event.allDay = true;
    }

    if (from.weeklyRecurring) {
      event.startTime = {
        hours: from.dateTime.hours(),
        minutes: from.dateTime.minutes(),
        seconds: from.dateTime.seconds(),
      };
      event.daysOfWeek = [from.dateTime.day()];
    }

    return event;
  }

  function _setStaticCalendarEvents(calendar, $calendar, post) {
    $(`<div>${post.cooked}</div>`)
      .find('.calendar[data-calendar-type="static"] p')
      .html()
      .trim()
      .split("<br>")
      .forEach((line) => {
        const html = $.parseHTML(line);
        const htmlDates = html.filter((h) =>
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
        hiddenDays.split(",").map((d) => parseInt(d, 10))
      );
    }

    calendar.setOption("eventClick", ({ event, jsEvent }) => {
      hidePopover(jsEvent);
      const { htmlContent, postNumber, postUrl } = event.extendedProps;

      if (postUrl) {
        DiscourseURL.routeTo(postUrl);
      } else if (postNumber) {
        _topicController =
          _topicController || api.container.lookup("controller:topic");
        _topicController.send("jumpToPost", postNumber);
      } else if (isMobileView && htmlContent) {
        showPopover(jsEvent, { htmlContent });
      }
    });

    calendar.setOption("eventMouseEnter", ({ event, jsEvent }) => {
      const { htmlContent } = event.extendedProps;
      if (!htmlContent) {
        return;
      }
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
            weeklyRecurring: detail.recurring === "1.weeks",
          }
        : null,
      detail.to
        ? {
            dateTime: moment(detail.to),
            weeklyRecurring: detail.recurring === "1.weeks",
          }
        : null
    );

    event.extendedProps = {};
    if (detail.post_url) {
      event.extendedProps.postUrl = detail.post_url;
    } else if (detail.post_number) {
      event.extendedProps.postNumber = detail.post_number;
    } else {
      event.classNames = ["holiday"];
    }

    return event;
  }

  function _addStandaloneEvent(calendar, post, detail) {
    const event = _buildEvent(detail);

    const holidayCalendarTopicId = parseInt(
      siteSettings.holiday_calendar_topic_id,
      10
    );

    const text = detail.message.split("\n").filter((e) => e);
    if (
      text.length &&
      post.topic_id &&
      holidayCalendarTopicId !== post.topic_id
    ) {
      event.title = text[0];
      event.extendedProps.description = text.slice(1).join(" ");
    } else {
      const color = stringToColor(detail.username);

      event.title = detail.username;
      event.backgroundColor = colorToHex(color);
      event.textColor = colorToHex(contrastColor(color));
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
    let htmlContent = "";
    let usernames = [];
    let localEventNames = [];

    Object.keys(detail.localEvents)
      .sort()
      .forEach((key) => {
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
      event.title = isMobileView
        ? usernames.length
        : `(${usernames.length}) ` + I18n.t("discourse_calendar.holiday");
    } else if (usernames.length === 1) {
      event.title = usernames[0];
    } else {
      event.title = isMobileView
        ? usernames.length
        : `(${usernames.length}) ` + usernames.slice(0, 3).join(", ");
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

  function _setDynamicCalendarEvents(calendar, post, fullDay) {
    const groupedEvents = [];

    (post.calendar_details || []).forEach((detail) => {
      switch (detail.type) {
        case "grouped":
          groupedEvents.push(detail);
          break;
        case "standalone":
          if (fullDay && detail.timezone) {
            detail.from = moment
              .tz(detail.from, detail.timezone)
              .format("YYYY-MM-DD");
            detail.to = moment
              .tz(detail.to, detail.timezone)
              .format("YYYY-MM-DD");
          }
          _addStandaloneEvent(calendar, post, detail);
          break;
      }
    });

    const formattedGroupedEvents = {};
    groupedEvents.forEach((groupedEvent) => {
      const minDate = fullDay
        ? moment(groupedEvent.from).format("YYYY-MM-DD")
        : moment(groupedEvent.from).utc().startOf("day").toISOString();
      const maxDate = fullDay
        ? moment(groupedEvent.to || groupedEvent.from).format("YYYY-MM-DD")
        : moment(groupedEvent.to || groupedEvent.from)
            .utc()
            .endOf("day")
            .toISOString();

      const identifier = `${minDate}-${maxDate}`;
      formattedGroupedEvents[identifier] = formattedGroupedEvents[
        identifier
      ] || {
        from: minDate,
        to: maxDate || minDate,
        localEvents: {},
      };

      formattedGroupedEvents[identifier].localEvents[
        groupedEvent.name
      ] = formattedGroupedEvents[identifier].localEvents[groupedEvent.name] || {
        usernames: [],
      };

      formattedGroupedEvents[identifier].localEvents[
        groupedEvent.name
      ].usernames.push.apply(
        formattedGroupedEvents[identifier].localEvents[groupedEvent.name]
          .usernames,
        groupedEvent.usernames
      );
    });

    Object.keys(formattedGroupedEvents).forEach((key) => {
      const formattedGroupedEvent = formattedGroupedEvents[key];
      _addGroupedEvent(calendar, post, formattedGroupedEvent);
    });
  }

  function _getTimeZone($calendar, currentUser) {
    let defaultTimezone = $calendar.attr("data-calendar-default-timezone");
    const isValidDefaultTimezone = !!moment.tz.zone(defaultTimezone);
    if (!isValidDefaultTimezone) {
      defaultTimezone = null;
    }

    return defaultTimezone || currentUser?.timezone || moment.tz.guess();
  }

  function _setupTimezonePicker(calendar, timezone) {
    let $timezonePicker = $(".discourse-calendar-timezone-picker");

    if ($timezonePicker.length) {
      $timezonePicker.on("change", function (event) {
        calendar.setOption("timeZone", event.target.value);
        _insertAddToCalendarLinks(calendar);
      });

      moment.tz.names().forEach((tz) => {
        $timezonePicker.append(new Option(tz, timezone));
      });

      $timezonePicker.val(timezone);
    } else {
      $(".discourse-calendar-timezone-wrap").text(timezone);
    }
  }

  function _insertAddToCalendarLinks(info) {
    if (info.view.type !== "listNextYear") {
      return;
    }

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
    if (!allDay) {
      return date.toISOString().replace(/-|:|\.\d\d\d/g, "");
    }

    return moment(date).utc().format("YYYYMMDD");
  }

  function _endDateForAllDayEvent(startDate, allDay) {
    const unit = allDay ? "days" : "hours";
    return _formatDateForGoogleApi(
      moment(startDate).add(1, unit).toDate(),
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
  },
};
