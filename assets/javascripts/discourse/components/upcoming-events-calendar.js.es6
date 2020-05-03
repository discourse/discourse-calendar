import { Promise } from "rsvp";
import { isNotFullDayEvent } from "discourse/plugins/discourse-calendar/lib/guess-best-date-format";
import { formatEventName } from "discourse/plugins/discourse-calendar/helpers/format-event-name";
import loadScript from "discourse/lib/load-script";
import Component from "@ember/component";
import { schedule } from "@ember/runloop";

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

  didReceiveAttrs() {
    this._super(...arguments);

    this._renderCalendar();
  },

  _renderCalendar() {
    const calendarNode = document.getElementById("upcoming-events-calendar");
    if (!calendarNode) {
      return;
    }

    calendarNode.innerHTML = "";

    if (this._calendar) {
      this._calendar.destroy();
      this._calendar = null;
    }

    this._loadCalendar().then(() => {
      this._calendar = new window.FullCalendar.Calendar(calendarNode, {});

      (this.events || []).forEach(event => {
        const { starts_at, ends_at, post } = event;
        this._calendar.addEvent({
          title: formatEventName(event),
          start: starts_at,
          end: ends_at || starts_at,
          allDay: !isNotFullDayEvent(moment(starts_at), moment(ends_at)),
          url: Discourse.getURL(`/t/-/${post.topic.id}/${post.post_number}`)
        });
      });

      this._calendar.render();
    });
  },

  _loadCalendar() {
    return new Promise(resolve => {
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
});
