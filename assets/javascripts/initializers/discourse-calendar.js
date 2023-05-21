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
import {
  colorToHex,
  contrastColor,
  stringToColor,
} from "discourse/plugins/discourse-calendar/lib/colors";
import { createPopper } from "@popperjs/core";
import { isNotFullDayEvent } from "discourse/plugins/discourse-calendar/lib/guess-best-date-format";
import { formatEventName } from "discourse/plugins/discourse-calendar/helpers/format-event-name";
import getURL from "discourse-common/lib/get-url";

function loadFullCalendar() {
  return new Promise((resolve) => {
    loadScript(
    "/plugins/discourse-calendar/javascripts/fullcalendar-v5.min.js",
    ).then(() => {
      loadScript("/plugins/discourse-calendar/javascripts/popper.min.js").then(() => {
        resolve();
      });
    });
  });
}

let eventPopper;
const EVENT_POPOVER_ID = "event-popover";

function initializeDiscourseCalendar(api) {
  const siteSettings = api.container.lookup("service:site-settings");

  if (siteSettings.login_required && !api.getCurrentUser()) {
    return;
  }

  const outletName = siteSettings.calendar_categories_outlet;

  const site = api.container.lookup("service:site");
  const isMobileView = site && site.mobileView;

  const selector = outletName;

  api.onPageChange((url, title) => {
    const $selector = $(selector);
    if (!$selector.length) return;

    if ($(`${selector} > .category-calendar`).length === 0) {
        $selector.prepend('<div class="category-calendar"></div>');
    }
    const $calendarContainer = $(`${selector} > .category-calendar`);

    $calendarContainer.hide();

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

    // Manage calendar with postId in categorySetting (extension setting)
    if (categorySetting && categorySetting.postId) {
    $calendarContainer.show();
    const postId = categorySetting.postId;
    const $spinner = $(
        '<div class="calendar"><div class="spinner medium"></div></div>'
    );
    $calendarContainer.html($spinner);
    loadFullCalendar().then(() => {
        const options = extractOptionalsCategorySettingOptions([`postId=${postId}`], categorySetting);

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
    }

      // Manage calendar with eventsFromCategory in categorySetting (extension setting)
      if (categorySetting && categorySetting.eventsFromCategory) {
        const { eventsFromCategory } = categorySetting;
        // Show container
        $calendarContainer.show();

        // Add a loader
        const $spinner = $(
          '<div class="calendar"><div class="spinner medium"></div></div>'
        );
        $calendarContainer.html($spinner);

        // Load fullcalendar.io script
        loadFullCalendar().then(() => {
            const options = extractOptionalsCategorySettingOptions([`eventsFromCategory=${eventsFromCategory}`], categorySetting);

            const rawCalendar = `[calendar ${options.join(" ")}]\n[/calendar]`;
            // Cooking calendar
            const cookRaw = cookAsync(rawCalendar);
            // Fetch event from category id
            const fetchEvents = ajax(`/discourse-post-event/events.json?category_id=${eventsFromCategory}&include_subcategories=true`);

            // Execute cooking and fetch events
            Promise.all([cookRaw, fetchEvents]).then((results) => {
              const cooked = results[0];
              const { events } = results[1];
              const $cooked = $(cooked.string);

              // Add calendar to DOM
              $calendarContainer.html($cooked);
              renderCalendarFromCategoryEvents($(".calendar", $cooked), events);
            })
        });
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

  /**
   * Extract optionals options from categorySetting ("calendar categories" in extension settings)
   *
   * @return array
  */
  function extractOptionalsCategorySettingOptions(options, categorySetting) {
    const optionals = ["weekends", "tzPicker", "defaultView"];

    optionals.forEach((optional) => {
      if (isPresent(categorySetting[optional])) {
        options.push(
          `${optional}=${escapeExpression(categorySetting[optional])}`
        );
      }
    });

    return options;
  }

  /**
   * Render a calendar with event from a category
   *
   * @returns Void
   */
  function renderCalendarFromCategoryEvents($calendar, events) {

      $calendar = $calendar.empty();
      const timezone = _getTimeZone($calendar, api.getCurrentUser());
      // Instantiate fullcalendar.io
      const calendar = _buildCalendar($calendar, timezone);

      calendar.render();
      _setupTimezonePicker(calendar, timezone);

      // Iterate events
      events.forEach(rawEvent => {
        const { post } = rawEvent;
        const { topic } = post;
        const { category_id } = topic;
        const category = Category.findById(category_id);
        const event = {
          title: formatEventName(rawEvent),
          start: rawEvent.starts_at,
          end: rawEvent.ends_at,
          extendedProps: {
            post,
            topic,
            category
          },
          url: rawEvent.post.url,
          color: `#${category.color}`
        };

        // Add a events
        calendar.addEvent(event);

      });
  }

  function render($calendar, post, siteSettings) {
    $calendar = $calendar.empty();

    const timezone = _getTimeZone($calendar, api.getCurrentUser());
    const calendar = _buildCalendar($calendar, timezone);
    const isStatic = $calendar.attr("data-calendar-type") === "static";
    const fullDay = $calendar.attr("data-calendar-full-day") === "true";
    const staticLines = getStaticLines(post);
    // const isStatic = staticLines.length > 0;

    if (isStatic) {
      calendar.render();
      _setStaticCalendarEvents(calendar, $calendar, staticLines);
    } else {
      // Get events from post of the topic
      _setDynamicCalendarEvents(calendar, post, siteSettings);
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

    const showAddToCalendar =
      $calendar.attr("data-calendar-show-add-to-calendar") !== "false";

    const $tooltip        = $('.calendar-tooltip');
    const $tooltipContent = $('.tooltip-content');
    const tooltipNode     = $tooltip[0];

    return new window.FullCalendar.Calendar($calendar[0], {
        timeZone: 'local',
        locale: siteSettings.default_locale,
        firstDay: siteSettings.default_locale === 'fr' ? 1 : 0,
        displayEventEnd: false,
        height: 725,
        headerToolbar: {
            left: 'prev,next today',
            center: 'title',
            right: 'dayGridMonth,timeGridWeek,timeGridDay,listMonth'
         },
        weekNumbers: true,
        navLinks: true, // can click day/week names to navigate views
        dayMaxEvents: true, // allow "more" link when too many events
        initialView: isMobileView ? "listMonth" : "dayGridMonth",

        eventDidMount: (info) => {
          const { el } = info;
          const  timeNode = el.querySelector('.fc-event-time');
          const dotNode = el.querySelector('.fc-daygrid-event-dot');
          const { style } = dotNode || el;
          const { borderColor } = style || {};
          if (borderColor) {
            timeNode.style.backgroundColor = borderColor;
          }
          if (showAddToCalendar) {
            _insertAddToCalendarLinks(info);
          }

          // $calendarTitle.innerText = info.view.title;
        },

        eventMouseEnter: function({event, el}) {
            const {
                start, end, title, backgroundColor, extendedProps
            }                 = event;
            const $category   = $('.category', $tooltipContent);
            const $title      = $('.title', $tooltipContent);
            const $ends       = $('.ends', $tooltipContent);
            const $endsDate   = $('.date', $ends);
            const $endsTime   = $('.time', $ends);
            const $starts     = $('.starts', $tooltipContent);
            const $startsDate = $('.date', $starts);
            const $startsTime = $('.time', $starts);

            const eventNode   = $('.fc-event-title, .fc-list-event-title > a', el)[0];

            const { category } = extendedProps;

            if (category) {
                $category.html(category.name);
            }

            $title.html(title);
            $tooltipContent.toggleClass('no-title', !title);

            $startsDate.html(start.toLocaleDateString());
            $startsTime.html(start.toLocaleTimeString());

            $endsDate.html(end ? end.toLocaleDateString() : "");
            $endsTime.html(end ? end.toLocaleTimeString() : "");

            $startsTime.toggle(!event.allDay);

            $tooltipContent.toggleClass('only-first-date', !end);

            $tooltip.show();
            this.tooltip = new window.Popper.createPopper(eventNode, tooltipNode, {
                placement: 'top',
                modifiers: [
                    {
                    name: 'offset',
                    options: {
                        offset: [0, 8],
                    },
                    },
                ],
            });
            tooltipNode.style.backgroundColor = backgroundColor;
        },
        eventMouseLeave: function({el}) {
            $tooltip.hide();
            this.tooltip = null;
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
      timeString: time
    };
  }

  function _buildEventObject(from, to) {
    const hasTimeSpecified = (d) => {
      return d.hours() !== 0 || d.minutes() !== 0 || d.seconds() !== 0;
    };

    let event = {
      start: from.dateTime.toDate(),
    };

    if (to) {
      if (hasTimeSpecified(to.dateTime) || hasTimeSpecified(from.dateTime)) {
        event.end = to.dateTime.toDate();
      }
    }
    if (!from.timeString){
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

  function getStaticLines(post) {
    const html = $(`<div>${post.cooked}</div>`)
        .find('.calendar p')
        .html();

    if (!html) {
        return [];
    }

    return html.trim().split("<br>");
  }


  function _setStaticCalendarEvents(calendar, $calendar, staticLines) {

    let lastLine = {};
    staticLines.forEach((line, index) => {
        const html = $.parseHTML(line);
        const htmlDates = html.filter((h) =>
          $(h).hasClass("discourse-local-date")
        );
        if (htmlDates.length === 0) {
            lastLine = { line, index };
            return;
        }

        const from = _convertHtmlToDate($(htmlDates[0]));
        const to = _convertHtmlToDate($(htmlDates[1]));

        let event = _buildEventObject(from, to);
        // Add previous line
        event.title = lastLine.index === index -1 ? lastLine.line : "";
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

  }


  function _buildEvent(detail) {
    const event = _buildEventObject(
      detail.from
        ? {
            dateTime: moment(detail.from),
            weeklyRecurring: detail.recurring === "1.weeks",
            timeString: detail.from
          }
        : null,
      detail.to
        ? {
            dateTime: moment(detail.to),
            weeklyRecurring: detail.recurring === "1.weeks",
            timeString: detail.to
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

  // Get event from post of the topic
  function _setDynamicCalendarEvents(calendar, post, siteSettings) {
    const groupedEvents = [];
    // TODO: fix calendar_details detail.from with time 00:00 for a no time defined event in a post
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

/* new add !?
    const eventSegments = info.view.eventRenderer.segs;
    const eventSegmentDefMap = _eventSegmentDefMap(info);

    for (const event of eventSegments) {
      _insertAddToCalendarLinkForEvent(event, eventSegmentDefMap);
    }
*/
    if (info.view.type !== "listMonth") return;
    _insertAddToCalendarLinkForEvent(info);
  }

  function _insertAddToCalendarLinkForEvent(info) {
    const { event, el } = info;
    const eventTitle = event.title;
    let startDate = event.start;
    let endDate = event.end;

    endDate = endDate
      ? _formatDateForGoogleApi(endDate, event.allDay)
      : _endDateForAllDayEvent(startDate, event.allDay);
    startDate = _formatDateForGoogleApi(startDate, event.allDay);

    const link = document.createElement("a");
    const title = I18n.t("discourse_calendar.add_to_calendar");
    link.title = title;
    link.appendChild(document.createTextNode(title));
    link.href = `
      http://www.google.com/calendar/event?action=TEMPLATE&text=${encodeURIComponent(
        eventTitle
      )}&dates=${startDate}/${endDate}&details=${encodeURIComponent(
      event.extendedProps.description
    )}`;
    link.target = "_blank";
    link.classList.add("fc-list-item-add-to-calendar");
    const rowNode = el.closest('.fc-list-event').previousSibling;
    el.querySelector(".fc-list-event-title").appendChild(link);
    el.onclick  = (e) => {
        e.stopPropagation();
    }
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
