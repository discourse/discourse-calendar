import RouteTemplate from "ember-route-template";
import UpcomingEventsCalendar from "discourse/plugins/discourse-calendar/discourse/components/upcoming-events-calendar";

export default RouteTemplate(
  <template>
    <div class="discourse-post-event-upcoming-events">
      <UpcomingEventsCalendar @events={{@controller.model}} />
    </div>
  </template>
);
