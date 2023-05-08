import { Promise } from "rsvp";
import { isNotFullDayEvent } from "discourse/plugins/discourse-calendar/lib/guess-best-date-format";
import { formatEventName } from "discourse/plugins/discourse-calendar/helpers/format-event-name";
import loadScript from "discourse/lib/load-script";
import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import getURL from "discourse-common/lib/get-url";

export default Component.extend({
  tagName: "",
  events: null,
  shouldShowEventInfo: false,
  eventData: null,
  eventInfoPosition: null,

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

  _calculatePosition(element) {
    const offsetLeft = element.offsetLeft;
    const offsetTop = element.offsetTop;
    const windowWidth = $(window).width();
    const windowHeight = $(window).height();

    let styles;

    if (offsetLeft > windowWidth / 2) {
      styles = {
        left: "-390px",
        right: "initial",
      };
    } else {
      styles = {
        right: "-390px",
        left: "initial",
      };
    }

    if (offsetTop > windowHeight / 2) {
      styles = Object.assign(styles, {
        bottom: "-15px",
        top: "initial",
      });
    } else {
      styles = Object.assign(styles, {
        top: "-15px",
        bottom: "initial",
      });
    }

    this.set("eventInfoPosition", styles);
  },

  _renderCalendar() {
    const calendarNode = document.getElementById("upcoming-events-calendar");
    if (!calendarNode) {
      return;
    }

    calendarNode.innerHTML = "";

    this._loadCalendar(this).then(() => {
      let eventThis = this;
      this._calendar = new window.FullCalendar.Calendar(calendarNode, {
        eventClick: function (info) {
          eventThis.set("eventData", info.event);
          eventThis.set("shouldShowEventInfo", true);
          eventThis._calculatePosition(info.el);
          info.jsEvent.preventDefault(); // prevents browser from following link in current tab.
        },
        eventMouseEnter: function (info) {
          let eventObj = info.event;
        },
      });

      (this.events || []).forEach((event) => {
        const { starts_at, ends_at, post, id } = event;
        this._calendar.addEvent({
          title: formatEventName(event),
          start: starts_at,
          end: ends_at || starts_at,
          allDay: !isNotFullDayEvent(moment(starts_at), moment(ends_at)),
          url: getURL(`/t/-/${post.topic.id}/${post.post_number}`),
          postId: id,
        });
      });

      this._calendar.render();
    });
  },

  _loadCalendar(context) {
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
