import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import { tagName } from "@ember-decorators/component";
import { Promise } from "rsvp";
import getURL from "discourse/lib/get-url";
import loadScript from "discourse/lib/load-script";
import Category from "discourse/models/category";
import { formatEventName } from "../helpers/format-event-name";
import addRecurrentEvents from "../lib/add-recurrent-events";
import fullCalendarDefaultOptions from "../lib/full-calendar-default-options";
import { isNotFullDayEvent } from "../lib/guess-best-date-format";
import { service } from "@ember/service";

@tagName("")
export default class UpcomingEventsCalendar extends Component {
  @service siteSettings;

  events = null;
  @tracked selectedCategories = [];

  init() {
    super.init(...arguments);
    this._calendar = null;
    this.selectedCategories = this.siteSettings.default_upcoming_events_calendar_categories.split("|").map((c) => parseInt(c));
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    this._calendar && this._calendar.destroy();
    this._calendar = null;
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    this._renderCalendar();
  }

  async _renderCalendar() {
    const siteSettings = this.site.siteSettings;

    const calendarNode = document.getElementById("upcoming-events-calendar");
    if (!calendarNode) {
      return;
    }

    calendarNode.innerHTML = "";

    await this._loadCalendar();

    const fullCalendar = new window.FullCalendar.Calendar(calendarNode, {
      ...fullCalendarDefaultOptions(),
      firstDay: 1,
      height: "auto",
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
      eventRender: (info) => {
        if (!this.selectedCategories.length) {
          return true
        }
        return this.selectedCategories.includes(info.event.extendedProps.categoryId)
      }
    });
    this._calendar = fullCalendar;

    const tagsColorsMap = JSON.parse(siteSettings.map_events_to_color);

    const resolvedEvents = await this.events;
    const originalEventAndRecurrents = addRecurrentEvents(resolvedEvents);

    (originalEventAndRecurrents || []).forEach((event) => {
      const { startsAt, endsAt, post, categoryId } = event;

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
            entry.type === "category" && entry.slug === post.topic.category_slug
        );
        backgroundColor = categoryColorEntry?.color;
      }

      const categoryColor = Category.findById(categoryId)?.color;
      if (!backgroundColor && categoryColor) {
        backgroundColor = `#${categoryColor}`;
      }

      let classNames;
      if (moment(endsAt || startsAt).isBefore(moment())) {
        classNames = "fc-past-event";
      }

      this._calendar.addEvent({
        title: formatEventName(event),
        start: startsAt,
        end: endsAt || startsAt,
        allDay: !isNotFullDayEvent(moment(startsAt), moment(endsAt)),
        url: getURL(`/t/-/${post.topic.id}/${post.post_number}`),
        backgroundColor,
        classNames,
        extendedProps: {
          categoryId: categoryId
        }
      });
    });

    this._calendar.render();
  }

  changeSelectedCategories = (value) => {
    this.selectedCategories = value;
    this._calendar.rerenderEvents()
  }

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
  }
}
