import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import { Promise } from "rsvp";
import loadScript from "discourse/lib/load-script";
import Category from "discourse/models/category";
import getURL from "discourse-common/lib/get-url";
import { formatEventName } from "../helpers/format-event-name";
import fullCalendarDefaultOptions from "../lib/full-calendar-default-options";
import { isNotFullDayEvent } from "../lib/guess-best-date-format";

export default Component.extend({
  tagName: "",
  events: null,

  init() {
    this._super(...arguments);

    this._calendar = null;
  },

  willDestroyElement() {
    this._super(...arguments);

    this._calendar && this._calendar.destroy();
    this._calendar = null;
  },

  didInsertElement() {
    this._super(...arguments);

    this._renderCalendar();
  },

  addRecurrentEvents(events) {
    events.forEach((event) => {
      event.upcoming_dates?.forEach((upcomingDate) => {
        events.push(
          Object.assign({}, event, {
            starts_at: upcomingDate.starts_at,
            ends_at: upcomingDate.ends_at,
            upcoming_dates: [],
          })
        );
      });
    });

    return events;
  },

  _renderCalendar() {
    const siteSettings = this.site.siteSettings;

    const calendarNode = document.getElementById("upcoming-events-calendar");
    if (!calendarNode) {
      return;
    }

    calendarNode.innerHTML = "";

    this._loadCalendar().then(() => {
      const fullCalendar = new window.FullCalendar.Calendar(calendarNode, {
        ...fullCalendarDefaultOptions(),
        eventPositioned: (info) => {
          if (siteSettings.events_max_rows === 0) {
            return;
          }

          let fcContent = info.el.querySelector(".fc-content");
          let computedStyle = window.getComputedStyle(fcContent);
          let lineHeight = parseInt(computedStyle.lineHeight, 10);

          if (lineHeight === 0) {
            lineHeight = 20;
          }
          let maxHeight = lineHeight * siteSettings.events_max_rows;

          if (fcContent) {
            fcContent.style.maxHeight = `${maxHeight}px`;
          }

          let fcTitle = info.el.querySelector(".fc-title");
          if (fcTitle) {
            fcTitle.style.overflow = "hidden";
            fcTitle.style.whiteSpace = "pre-wrap";
          }
          fullCalendar.updateSize();
        },
      });
      this._calendar = fullCalendar;

      const tagsColorsMap = JSON.parse(siteSettings.map_events_to_color);

      const originalEventAndRecurrents = this.addRecurrentEvents(
        this.events.content
      );

      (originalEventAndRecurrents || []).forEach((event) => {
        const { starts_at, ends_at, post, category_id } = event;

        let backgroundColor;

        if (post.topic.tags) {
          const tagColorEntry = tagsColorsMap.find(
            (entry) =>
              entry.type === "tag" && post.topic.tags.includes(entry.slug)
          );
          backgroundColor = tagColorEntry?.color;
        }

        if (!backgroundColor) {
          const categoryColorEntry = tagsColorsMap.find(
            (entry) =>
              entry.type === "category" &&
              entry.slug === post.topic.category_slug
          );
          backgroundColor = categoryColorEntry?.color;
        }

        const categoryColor = Category.findById(category_id)?.color;
        if (!backgroundColor && categoryColor) {
          backgroundColor = `#${categoryColor}`;
        }

        let classNames;
        if (moment(ends_at || starts_at).isBefore(moment())) {
          classNames = "fc-past-event";
        }

        this._calendar.addEvent({
          title: formatEventName(event),
          start: starts_at,
          end: ends_at || starts_at,
          allDay: !isNotFullDayEvent(moment(starts_at), moment(ends_at)),
          url: getURL(`/t/-/${post.topic.id}/${post.post_number}`),
          backgroundColor,
          classNames,
        });
      });

      this._calendar.render();
    });
  },

  _loadCalendar() {
    return new Promise((resolve) => {
      loadScript(
        "/plugins/discourse-calendar/javascripts/fullcalendar-with-moment-timezone.min.js"
      ).then(() => {
        schedule("afterRender", () => {
          if (this.isDestroying || this.isDestroyed) {
            return;
          }

          resolve();
        });
      });
    });
  },
});
