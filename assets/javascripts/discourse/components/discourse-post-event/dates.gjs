import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import { applyLocalDates } from "discourse/lib/local-dates";
import { cook } from "discourse/lib/text";
import guessDateFormat from "../../lib/guess-best-date-format";

export default class DiscoursePostEventDates extends Component {
  @service siteSettings;

  @tracked htmlDates = "";

  get startsAt() {
    return moment(this.args.event.startsAt).tz(this.timezone);
  }

  get endsAt() {
    return (
      this.args.event.endsAt && moment(this.args.event.endsAt).tz(this.timezone)
    );
  }

  get timezone() {
    return this.args.event.timezone || "UTC";
  }

  get format() {
    return guessDateFormat(this.startsAt, this.endsAt);
  }

  get datesBBCode() {
    const dates = [];

    dates.push(this.buildDateBBCode(this.startsAt));

    if (this.endsAt) {
      dates.push(this.buildDateBBCode(this.endsAt));
    }

    return dates;
  }

  buildDateBBCode(date) {
    const bbcode = {
      date: date.format("YYYY-MM-DD"),
      time: date.format("HH:mm"),
      format: this.format,
      timezone: this.timezone,
    };

    if (this.args.event.showLocalTime) {
      bbcode.displayedTimezone = this.args.event.timezone;
    }

    const content = Object.entries(bbcode)
      .map(([key, value]) => `${key}=${value}`)
      .join(" ");

    return `[${content}]`;
  }

  @action
  async computeDates(element) {
    if (this.siteSettings.discourse_local_dates_enabled) {
      const result = await cook(this.datesBBCode.join("<span> → </span>"));
      this.htmlDates = htmlSafe(result.toString());

      next(() => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        applyLocalDates(
          element.querySelectorAll(
            `[data-post-id="${this.args.event.id}"] .discourse-local-date`
          ),
          this.siteSettings
        );
      });
    } else {
      let dates = `${this.startsAt.format(this.format)}`;
      if (this.endsAt) {
        dates += ` → ${moment(this.endsAt).format(this.format)}`;
      }
      this.htmlDates = htmlSafe(dates);
    }
  }

  <template>
    <section class="event__section event-dates" {{didInsert this.computeDates}}>
      {{icon "clock"}}{{this.htmlDates}}</section>
  </template>
}
