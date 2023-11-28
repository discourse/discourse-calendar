import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import { Promise } from "rsvp";
import loadScript from "discourse/lib/load-script";
import getURL from "discourse-common/lib/get-url";
import { formatEventName } from "../helpers/format-event-name";
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
    const calendarNode = document.getElementById("upcoming-events-calendar");
    if (!calendarNode) {
      return;
    }

    calendarNode.innerHTML = "";

    this._loadCalendar().then(() => {
      this._calendar = new window.FullCalendar.Calendar(calendarNode, {});

      const originalEventAndRecurrents = this.addRecurrentEvents(
        this.events.content
      );

      (originalEventAndRecurrents || []).forEach((event) => {
        const { starts_at, ends_at, post, category_id } = event;
        const categoryColor = this.site.categoriesById[category_id]?.color;
        const backgroundColor = categoryColor ? `#${categoryColor}` : undefined;
        this._calendar.addEvent({
          title: formatEventName(event),
          start: starts_at,
          end: ends_at || starts_at,
          allDay: !isNotFullDayEvent(moment(starts_at), moment(ends_at)),
          url: getURL(`/t/-/${post.topic.id}/${post.post_number}`),
          backgroundColor,
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
