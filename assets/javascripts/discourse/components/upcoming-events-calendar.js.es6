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
    const $calendar       = $('.calendar');
    const $tooltip        = $('.calendar-tooltip');
    const $tooltipContent = $('.tooltip-content');

    if (!$calendar.length) {
      return;
    }

    const calendarNode = $calendar[0];
    const tooltipNode = $tooltip[0];

    $calendar.html('');

    this._loadCalendar().then(() => {
      this._calendar = new window.FullCalendar.Calendar(calendarNode, {
        timeZone: 'local',
        locale: 'fr',
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
        /*
        datesRender: (info) => {
          if (showAddToCalendar) {
            _insertAddToCalendarLinks(info);
          }

          $calendarTitle.innerText = info.view.title;
        },
        */
        eventMouseEnter: function({event, el}) {
            const { start, end, title } = event;
            const $title                = $('.title', $tooltipContent);
            const $ends                 = $('.ends', $tooltipContent);
            const $endsDate             = $('.date', $ends);
            const $endsTime             = $('.time', $ends);
            const $starts               = $('.starts', $tooltipContent);
            const $startsDate           = $('.date', $starts);
            const $startsTime           = $('.time', $starts);

            const eventnode             = $('.fc-event-title', el)[0];

            $title.html(title);
            $tooltipContent.toggleClass('no-title', !title);

            $startsDate.html(start.toLocaleDateString());
            $startsTime.html(start.toLocaleTimeString());

            $endsDate.html(end ? end.toLocaleDateString() : "");
            $endsTime.html(end ? start.toLocaleTimeString() : "");

            $startsTime.toggle(!event.allDay);

            $tooltipContent.toggleClass('only-first-date', !end);

            $tooltip.show();
            this.tooltip = new window.Popper.createPopper(eventnode, tooltipNode, {
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
        },
        eventMouseLeave: function({el}) {
            $tooltip.hide();
            this.tooltip = null;
        },
      });

      (this.events || []).forEach((event) => {
        const { starts_at, ends_at, post } = event;
        // const duration = moment.duration(moment(ends_at).diff(moment(starts_at))).asDays();
        this._calendar.addEvent({
          title: formatEventName(event),
          start: starts_at,
          end: ends_at || starts_at,
          url: getURL(`/t/-/${post.topic.id}/${post.post_number}`),
        });
      });

      this._calendar.render();
    });
  },

  _loadCalendar() {
    return new Promise((resolve) => {
      loadScript(
        "/plugins/discourse-calendar/javascripts/fullcalendar-v5.min.js",
      ).then(() => {
        loadScript("/plugins/discourse-calendar/javascripts/popper.min.js").then(() => {
            schedule("afterRender", () => {
            if (this.isDestroying || this.isDestroyed) {
                return;
            }

            resolve();
            });
        });
      });
    });
  },
});
