import Component from "@glimmer/component";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";
import { bind, next, scheduleOnce } from "@ember/runloop";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

function parseTimestamp(timestamp) {
  if (timestamp) {
    const [date, time] = timestamp.split("T");
    return { date, time };
  }
}

export default class EventInfo extends Component {
  @service store;
  @tracked eventModel;
  @tracked transformed;

  @action
  setPlacement(element) {
    console.log(this.args);
  }

  @action
  setupEventInfo() {
    this.clickHander = bind(this, this.documentClick);
    next(() => $(document).on("mousedown", this.get("clickHander")));
  }

  clickOutside() {
    this.close();
  }

  willDestroyElement() {
    $(document).off("mousedown", this.get("clickHandler"));
  }

  documentClick(event) {
    if (
      !event.target.closest(
        `div.events-calendar-card[data-topic-id='${this.topic.id}']`
      )
    ) {
      this.clickOutside();
    }
  }

  @action
  fetchEventData() {
    this.store
      .find(
        "discourse-post-event-event",
        this.args.discourseEvent.extendedProps.postId
      )
      .then((eventModel) => {
        const startsAt = parseTimestamp(eventModel.starts_at);
        const endsAt = parseTimestamp(eventModel.ends_at);

        this.eventModel = eventModel;

        this.transformed = {
          startsAt,
          endsAt,
          eventStatusLabel: I18n.t(
            `discourse_post_event.models.event.status.${eventModel.status}.title`
          ),
          eventStatusDescription: I18n.t(
            `discourse_post_event.models.event.status.${eventModel.status}.description`
          ),
          startsAtMonth: moment(eventModel.starts_at).format("MMM"),
          startsAtDay: moment(eventModel.starts_at).format("D"),
          eventName: emojiUnescape(
            escapeExpression(eventModel.name) ||
              this._cleanTopicTitle(
                eventModel.post.topic.title,
                eventModel.starts_at
              )
          ),
          statusClass: `status ${eventModel.status}`,
          isPublicEvent: eventModel.status === "public",
          isStandaloneEvent: eventModel.status === "standalone",
        };
      });
  }
}
