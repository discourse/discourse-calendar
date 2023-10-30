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

  _renderCalendar() {
    const calendarNode = document.getElementById("upcoming-events-calendar");
    if (!calendarNode) {
      return;
    }

    calendarNode.innerHTML = "";

    this._loadCalendar().then(() => {
      this._calendar = new window.FullCalendar.Calendar(calendarNode, {});

      (this.events || []).forEach((event) => {
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
