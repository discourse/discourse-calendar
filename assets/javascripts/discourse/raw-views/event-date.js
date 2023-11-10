import EmberObject, { computed } from "@ember/object";
import I18n from "I18n";
import guessDateFormat from "../lib/guess-best-date-format";

export default class EventDate extends EmberObject {
  @computed("topic.event_starts_at", "topic.event_ends_at")
  get shouldRender() {
    return (
      this.siteSettings.discourse_post_event_enabled &&
      this.get("topic.event_starts_at") &&
      this.get("topic.event_ends_at")
    );
  }

  get shouldUseLocalDate() {
    return this.siteSettings.use_local_event_date;
  }

  @computed("topic.event_starts_at")
  get eventStartedAt() {
    return this._parsedDate(this.get("topic.event_starts_at"));
  }

  @computed("topic.event_ends_at")
  get eventEndedAt() {
    return this._parsedDate(this.get("topic.event_ends_at"));
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
    // current dateType uses a different implementation
    const relativeDates = {
      future: this.eventStartedAt.from(moment()),
      past: this.eventEndedAt.from(moment()),
    };
    return relativeDates[this.relativeDateType];
  }

  get timeRemainingContent() {
    return I18n.t("discourse_post_event.topic_title.ends_in_duration", {
      duration: this.eventEndedAt.from(moment()),
    });
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
