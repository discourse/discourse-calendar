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

    loadScript(
      "/plugins/discourse-calendar/javascripts/fullcalendar-with-moment-timezone.min.js"
    ).then(() => {
      schedule("afterRender", () => {
        const calendarNode = document.getElementById("events-calendar");
        this._calendar = new window.FullCalendar.Calendar(calendarNode, {});
      });
    });
  },

  didUpdateAttrs() {
    this._super(...arguments);

    (this.events || []).forEach(event => {
      this._calendar.addEvent({
        title: formatEventName(event),
        start: event.starts_at,
        end: event.ends_at || event.starts_at,
        allDay: !isNotFullDayEvent(
          moment(event.starts_at),
          moment(event.ends_at)
        ),
        url: Discourse.getURL(
          `/t/-/${event.post.topic.id}/${event.post.post_number}`
        )
      });
    });
    this._calendar.render();
  }
});
