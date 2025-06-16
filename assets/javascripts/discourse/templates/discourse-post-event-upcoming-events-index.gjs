import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import RouteTemplate from "ember-route-template";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import UpcomingEventsCalendar from "../components/upcoming-events-calendar";

class UpcomingEventsIndex extends Component {
  @tracked filter = "all";

  @action
  changeFilter(newFilter) {
    this.filter = newFilter;
  }

  <template>
    <div class="events-filter">
      <DButton
        @label="discourse_post_event.upcoming_events.all_events"
        @action={{fn this.changeFilter "all"}}
        class="btn-small
          {{if (eq this.filter 'all') 'btn-primary' 'btn-default'}}"
      />
      <DButton
        @label="discourse_post_event.upcoming_events.my_events"
        @action={{fn this.changeFilter "mine"}}
        class="btn-small
          {{if (eq this.filter 'mine') 'btn-primary' 'btn-default'}}"
      />
    </div>
  </template>
}

export default RouteTemplate(
  <template>
    <div class="discourse-post-event-upcoming-events">
      <UpcomingEventsIndex @controller={{@controller}} />
      <UpcomingEventsCalendar @events={{@controller.model}} />
    </div>
  </template>
);
