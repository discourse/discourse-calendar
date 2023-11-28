import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import I18n from "discourse-i18n";
import guessDateFormat from "../lib/guess-best-date-format";

export default class EventDate extends Component {
  @service siteSettings;

  <template>
    {{#if this.shouldRender}}
      <div class="header-topic-title-suffix-outlet event-date-container">
        {{#if this.siteSettings.use_local_event_date}}
          <span
            class="event-date event-local-date past"
            title={{this.dateRange}}
            data-starts-at={{this.eventStartedAt}}
            data-ends-at={{this.eventEndedAt}}
          >
            {{this.localDateContent}}
          </span>
        {{else}}
          <span
            class="event-date event-relative-date {{this.relativeDateType}}"
            title={{this.dateRange}}
            data-starts-at={{this.eventStartedAt}}
            data-ends-at={{this.eventEndedAt}}
          >
            {{#if this.isWithinDateRange}}
              <div class="indicator"></div>
              <span class="text">{{this.timeRemainingContent}}</span>
            {{else}}
              {{this.relativeDateContent}}
            {{/if}}
          </span>
        {{/if}}
      </div>
    {{/if}}
  </template>

  get shouldRender() {
    return (
      this.siteSettings.discourse_post_event_enabled &&
      this.args.topic.event_starts_at &&
      this.args.topic.event_ends_at
    );
  }

  get eventStartedAt() {
    return this._parsedDate(this.args.topic.event_starts_at);
  }

  get eventEndedAt() {
    return this._parsedDate(this.args.topic.event_ends_at);
  }

  get dateRange() {
    return this.eventEndedAt
      ? `${this._formattedDate(this.eventStartedAt)} → ${this._formattedDate(
          this.eventEndedAt
        )}`
      : this._formattedDate(this.eventStartedAt);
  }

  get localDateContent() {
    return this._formattedDate(this.eventStartedAt);
  }

  get relativeDateType() {
    if (this.isWithinDateRange) {
      return "current";
    }
    if (this.eventStartedAt.isAfter(moment())) {
      return "future";
    }
    return "past";
  }

  get isWithinDateRange() {
    return (
      this.eventStartedAt.isBefore(moment()) &&
      this.eventEndedAt.isAfter(moment())
    );
  }

  get relativeDateContent() {
    // dateType "current" uses a different implementation
    const relativeDates = {
      future: this.eventStartedAt.from(moment()),
      past: this.eventEndedAt.from(moment()),
    };
    return relativeDates[this.relativeDateType];
  }

  get timeRemainingContent() {
    return I18n.t(
      "discourse_calendar.discourse_post_event.topic_title.ends_in_duration",
      {
        duration: this.eventEndedAt.from(moment()),
      }
    );
  }

  _parsedDate(date) {
    return moment.utc(date).tz(moment.tz.guess());
  }

  _guessedDateFormat() {
    return guessDateFormat(this.eventStartedAt);
  }

  _formattedDate(date) {
    return date.format(this._guessedDateFormat());
  }
}
