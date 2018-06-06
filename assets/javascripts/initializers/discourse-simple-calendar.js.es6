import loadScript from "discourse/lib/load-script";
import { default as computed } from "ember-addons/ember-computed-decorators";
import { withPluginApi } from "discourse/lib/plugin-api";
import { minimumOffset } from 'discourse/lib/offset-calculator';
import {ajax} from 'discourse/lib/ajax';

// https://stackoverflow.com/a/16348977
function stringToHexColor(str) {
  var hash = 0;
  for (var i = 0; i < str.length; i++) {
    hash = str.charCodeAt(i) + ((hash << 5) - hash);
  }
  var hex = '#';
  for (var i = 0; i < 3; i++) {
    var value = (hash >> (i * 8)) & 0xFF;
    hex += ('00' + value.toString(16)).substr(-2);
  }
  return hex;
}

function initializeDiscourseSimpleCalendar(api) {
  function calendarChanged(topicsController, message) {
    const stream = topicsController.get("model.postStream");
    const post = stream.findLoadedPost(stream.get("firstPostId"));
    const $op = $(".topic-post article#post_1");
    const $calendar = $op.find(".calendar").first();

    if (post && $calendar.length > 0) {
      ajax(`/posts/${post.id}.json`).then(data => {
        render($calendar, data);
      });
    }
  }
  api.registerCustomPostMessageCallback("calendar_change", calendarChanged);

  function render($calendar, post) {
    loadScript("/plugins/discourse-simple-calendar/javascripts/fullcalendar.min.js").then(() => {
      const events = post.calendar_details.map(detail => {
        let event =  {
          title: `${detail.username}: ${detail.message}`,
          color: stringToHexColor(detail.username),
          postNumber: parseInt(detail.post_number, 10),
          allDay: true
        }

        if (detail.to) {
          event.start = moment(detail.from);
          event.end = moment(detail.to);
        } else {
          event.start = moment(detail.from).format("YYYY-MM-DD");
        }

        return event;
      });

      if ($calendar.hasClass("fc")) {
        $calendar.fullCalendar("destroy");
      }

      $calendar
        .fullCalendar({
          eventClick: (calEvent, jsEvent, view) => {
            const $post = $(`.topic-post article#post_${calEvent.postNumber}`);
            $(window).scrollTop($post.offset().top - minimumOffset());
          },
          events
        });
    });
  }

  function attachCalendar($elem, helper) {
    const $calendar = $(".calendar", $elem);

    if ($calendar.length === 0) {
      return;
    }

    render($calendar, helper.getModel());
  }
  api.decorateCooked(attachCalendar, {onlyStream: true});
}

export default {
  name: "discourse-simple-calendar",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.discourse_simple_calendar_enabled) {
      withPluginApi("0.8.22", initializeDiscourseSimpleCalendar);
    }
  }
};
