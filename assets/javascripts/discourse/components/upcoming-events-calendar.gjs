import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import { tagName } from "@ember-decorators/component";
import { Calendar } from "@fullcalendar/core";
import dayGridPlugin from "@fullcalendar/daygrid";
import listPlugin from "@fullcalendar/list";
import timeGridPlugin from "@fullcalendar/timegrid";
import { Promise } from "rsvp";
import getURL from "discourse/lib/get-url";
import loadScript from "discourse/lib/load-script";
import Category from "discourse/models/category";
import { formatEventName } from "../helpers/format-event-name";
import addRecurrentEvents from "../lib/add-recurrent-events";
import fullCalendarDefaultOptions from "../lib/full-calendar-default-options";
import { isNotFullDayEvent } from "../lib/guess-best-date-format";

@tagName("")
export default class UpcomingEventsCalendar extends Component {
  events = null;

  init() {
    super.init(...arguments);
    this._calendar = null;
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

    const fullCalendar = new Calendar(calendarNode, {
      ...fullCalendarDefaultOptions(),
      plugins: [dayGridPlugin, timeGridPlugin, listPlugin],
      firstDay: 1,
      height: "auto",
      initialView: "dayGridMonth",
      eventDisplay: "auto",
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
      headerToolbar: {
        left: "prev,next today",
        center: "title",
        right: "dayGridMonth,timeGridDay,listNextYear",
      },
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
      });
    });

    this._calendar.render();
  }

  <template>
    <div id="upcoming-events-calendar"></div>
  </template>
}
