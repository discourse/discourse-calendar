import { Promise } from "rsvp";
import { isPresent } from "@ember/utils";
import DiscourseURL from "discourse/lib/url";
import { cookAsync } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import loadScript from "discourse/lib/load-script";
import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import I18n from "I18n";
import { colorToHex, contrastColor, stringToColor } from "../lib/colors";
import { createPopper } from "@popperjs/core";
import { isNotFullDayEvent } from "../lib/guess-best-date-format";
import { formatEventName } from "../helpers/format-event-name";
import getURL from "discourse-common/lib/get-url";

function loadFullCalendar() {
  return loadScript(
    "/plugins/discourse-calendar/javascripts/fullcalendar-with-moment-timezone.min.js"
  );
}

let eventPopper;
const EVENT_POPOVER_ID = "event-popover";

function initializeDiscourseCalendar(api) {
  const siteSettings = api.container.lookup("service:site-settings");

  if (siteSettings.login_required && !api.getCurrentUser()) {
    return;
  }

  let _topicController;
  const outletName = siteSettings.calendar_categories_outlet;

  const site = api.container.lookup("service:site");
  const isMobileView = site && site.mobileView;

  let selector = `.${outletName}-outlet`;
  if (outletName === "before-topic-list-body") {
    selector = `.topic-list:not(.shared-drafts) .${outletName}-outlet`;
  }

  api.onPageChange((url) => {
    const categoryCalendarNode = document.querySelector(
      `${selector}.category-calendar`
    );
    if (categoryCalendarNode) {
      categoryCalendarNode.innerHTML = "";
    }

    const categoryEventNode = document.getElementById(
      "category-events-calendar"
    );
    if (categoryEventNode) {
      categoryEventNode.innerHTML = "";
    }

    const browsedCategory = Category.findBySlugPathWithID(url);
    if (!browsedCategory) {
      return;
    }

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

    if (categoryCalendarNode && categorySetting && categorySetting.postId) {
      const postId = categorySetting.postId;
      categoryCalendarNode.innerHTML =
        '<div class="calendar"><div class="spinner medium"></div></div>';

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
          categoryCalendarNode.innerHTML = cooked.string;
          render($(".calendar"), post);
        });
      });
    } else {
      if (!categoryEventNode) {
        return;
      }

      const eventSettings = siteSettings.events_calendar_categories.split("|");
      const foundCategory = eventSettings.find(
        (k) => k === browsedCategory.id.toString()
      );

      if (foundCategory) {
        loadFullCalendar().then(() => {
          let calendar = new window.FullCalendar.Calendar(
            categoryEventNode,
            {}
          );
          const loadEvents = ajax(
            `/discourse-post-event/events.json?category_id=${browsedCategory.id}`
          );

          Promise.all([loadEvents]).then((results) => {
            const events = results[0];

            events[Object.keys(events)[0]].forEach((event) => {
              const { starts_at, ends_at, post } = event;
              calendar.addEvent({
                title: formatEventName(event),
                start: starts_at,
                end: ends_at || starts_at,
                allDay: !isNotFullDayEvent(moment(starts_at), moment(ends_at)),
                url: getURL(`/t/-/${post.topic.id}/${post.post_number}`),
              });
            });

            calendar.render();
          });
        });
      }
    }
  });

  api.decorateCooked(($elem, helper) => attachCalendar($elem, helper), {
    onlyStream: true,
    id: "discourse-calendar",
  });

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

  if (api.registerNotificationTypeRenderer) {
    api.registerNotificationTypeRenderer(
      "event_reminder",
      (NotificationTypeBase) => {
        return class extends NotificationTypeBase {
          get linkTitle() {
            if (this.notification.data.title) {
              return I18n.t(this.notification.data.title);
            } else {
              return super.linkTitle;
            }
          }

          get icon() {
            return "calendar-day";
          }

          get label() {
            return I18n.t(this.notification.data.message);
          }

          get description() {
            return this.notification.data.topic_title;
          }
        };
      }
    );
    api.registerNotificationTypeRenderer(
      "event_invitation",
      (NotificationTypeBase) => {
        return class extends NotificationTypeBase {
          get icon() {
            return "calendar-day";
          }

          get label() {
            if (
              this.notification.data.message ===
              "discourse_post_event.notifications.invite_user_predefined_attendance_notification"
            ) {
              return I18n.t(this.notification.data.message, {
                username: this.username,
              });
            }
            return super.label;
          }

          get description() {
            return this.notification.data.topic_title;
          }
        };
      }
    );
  }

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
      _setDynamicCalendarEvents(calendar, post, fullDay, timezone);
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

      eventRender: (info) => {
        _setTimezoneOffset(info);
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

  function _buildPopover(jsEvent, htmlContent) {
    const node = document.createElement("div");
    node.setAttribute("id", EVENT_POPOVER_ID);
    node.innerHTML = htmlContent;

    const arrow = document.createElement("span");
    arrow.dataset.popperArrow = true;
    node.appendChild(arrow);
    document.body.appendChild(node);

    eventPopper = createPopper(
      jsEvent.target,
      document.getElementById(EVENT_POPOVER_ID),
      {
        placement: "bottom",
        modifiers: [
          {
            name: "arrow",
          },
          {
            name: "offset",
            options: {
              offset: [20, 10],
            },
          },
        ],
      }
    );
  }

  function _destroyPopover() {
    eventPopper?.destroy();
    document.getElementById(EVENT_POPOVER_ID)?.remove();
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
      _destroyPopover();
      const { htmlContent, postNumber, postUrl } = event.extendedProps;

      if (postUrl) {
        DiscourseURL.routeTo(postUrl);
      } else if (postNumber) {
        _topicController =
          _topicController || api.container.lookup("controller:topic");
        _topicController.send("jumpToPost", postNumber);
      } else if (isMobileView && htmlContent) {
        _buildPopover(jsEvent, htmlContent);
      }
    });

    calendar.setOption("eventMouseEnter", ({ event, jsEvent }) => {
      _destroyPopover();
      const { htmlContent } = event.extendedProps;
      _buildPopover(jsEvent, htmlContent);
    });

    calendar.setOption("eventMouseLeave", () => {
      _destroyPopover();
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

    if (detail.timezoneOffset) {
      event.extendedProps.timezoneOffset = detail.timezoneOffset;
      event.extendedProps.eventDaysDuration = detail.eventDaysDuration;
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

    let popupText = detail.message.slice(0, 100);
    if (detail.message.length > 100) {
      popupText += "…";
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

    if (usernames.length > 2) {
      event.title = `(${usernames.length}) ${localEventNames[0]}`;
    } else if (usernames.length === 1) {
      event.title = usernames[0];
    } else {
      event.title = isMobileView
        ? `(${usernames.length}) ${localEventNames[0]}`
        : `(${usernames.length}) ` + usernames.join(", ");
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

  function _setDynamicCalendarEvents(calendar, post, fullDay, timezone) {
    const groupedEvents = [];
    const calendarUtcOffset = moment.tz(timezone).utcOffset();

    (post.calendar_details || []).forEach((detail) => {
      switch (detail.type) {
        case "grouped":
          groupedEvents.push(detail);
          break;
        case "standalone":
          if (fullDay && detail.timezone) {
            detail.from = moment.tz(detail.from, detail.timezone);
            detail.to = moment.tz(detail.to, detail.timezone);

            const eventUtcOffset = moment.tz(detail.timezone).utcOffset();
            const timezoneOffset = (calendarUtcOffset - eventUtcOffset) / 60;
            detail.timezoneOffset = timezoneOffset;
            detail.eventDaysDuration =
              detail.to.diff(detail.from, "days") + 1 || 1;

            if (timezoneOffset > 0) {
              if (detail.to.isValid()) {
                detail.to.add(1, "day");
              } else {
                detail.to = detail.from.clone().add(1, "day");
              }
            } else if (timezoneOffset < 0) {
              if (!detail.to.isValid()) {
                detail.to = detail.from.clone();
              }
              detail.from.subtract(1, "day");
            }

            detail.from = detail.from.format("YYYY-MM-DD");
            detail.to = detail.to.format("YYYY-MM-DD");
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

      formattedGroupedEvents[identifier].localEvents[groupedEvent.name] =
        formattedGroupedEvents[identifier].localEvents[groupedEvent.name] || {
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
    const tzPicker = document.querySelector(
      ".discourse-calendar-timezone-picker"
    );
    if (tzPicker) {
      tzPicker.addEventListener("change", function (event) {
        calendar.setOption("timeZone", event.target.value);
        _insertAddToCalendarLinks(calendar);
      });

      moment.tz.names().forEach((tz) => {
        tzPicker.appendChild(new Option(tz, tz));
      });

      tzPicker.value = timezone;
    } else {
      document.querySelector(".discourse-calendar-timezone-wrap").innerText =
        timezone;
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

  function _setTimezoneOffset(info) {
    const timezoneOffset = info.event.extendedProps.timezoneOffset;
    const eventDaysDuration = info.event.extendedProps.eventDaysDuration;
    if (timezoneOffset) {
      const baseOffset = 100 / (eventDaysDuration + 1);
      const pxOffset = `${3.5 - (eventDaysDuration - 1) / 2.5}px`;

      const notStart = info.el.classList.contains("fc-not-start");
      const notEnd = info.el.classList.contains("fc-not-end");

      if (timezoneOffset > 0) {
        if (!notStart) {
          const leftK = Math.abs(timezoneOffset) / 24;
          const pctOffset = `${baseOffset * leftK * (notEnd ? 2 : 1)}%`;
          info.el.style.marginLeft = `calc(${pctOffset} + ${pxOffset})`;
        }
        if (!notEnd) {
          const rightK = (24 - Math.abs(timezoneOffset)) / 24;
          const pctOffset = `${baseOffset * rightK * (notStart ? 2 : 1)}%`;
          info.el.style.marginRight = `calc(${pctOffset} + ${pxOffset})`;
        }
      } else if (timezoneOffset < 0) {
        if (!notStart) {
          const leftK = (24 - Math.abs(timezoneOffset)) / 24;
          const pctOffset = `${baseOffset * leftK * (notEnd ? 2 : 1)}%`;
          info.el.style.marginLeft = `calc(${pctOffset} + ${pxOffset})`;
        }
        if (!notEnd) {
          const rightK = Math.abs(timezoneOffset) / 24;
          const pctOffset = `${baseOffset * rightK * (notStart ? 2 : 1)}%`;
          info.el.style.marginRight = `calc(${pctOffset} + ${pxOffset})`;
        }
      }
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
    const siteSettings = container.lookup("service:site-settings");
    if (siteSettings.calendar_enabled) {
      withPluginApi("0.8.22", initializeDiscourseCalendar);
    }
  },
};
