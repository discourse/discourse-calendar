import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import I18n from "discourse-i18n";
import or from "truth-helpers/helpers/or";
import { isNotFullDayEvent } from "../lib/guess-best-date-format";

export const DEFAULT_MONTH_FORMAT = "MMMM YYYY";
export const DEFAULT_DATE_FORMAT = "dddd, MMM D";
export const DEFAULT_TIME_FORMAT = "LT";
const DEFAULT_COUNT = 8;

export default class UpcomingEventsList extends Component {
  @service appEvents;
  @service siteSettings;
  @service router;

  @tracked isLoading = true;
  @tracked hasError = false;
  @tracked eventsByMonth = {};

  monthFormat = this.args.params?.monthFormat ?? DEFAULT_MONTH_FORMAT;
  dateFormat = this.args.params?.dateFormat ?? DEFAULT_DATE_FORMAT;
  timeFormat = this.args.params?.timeFormat ?? DEFAULT_TIME_FORMAT;
  count = this.args.params?.count ?? DEFAULT_COUNT;

  title = I18n.t(
    "discourse_calendar.discourse_post_event.upcoming_events_list.title"
  );
  emptyMessage = I18n.t(
    "discourse_calendar.discourse_post_event.upcoming_events_list.empty"
  );
  allDayLabel = I18n.t(
    "discourse_calendar.discourse_post_event.upcoming_events_list.all_day"
  );
  errorMessage = I18n.t(
    "discourse_calendar.discourse_post_event.upcoming_events_list.error"
  );
  viewAllLabel = I18n.t(
    "discourse_calendar.discourse_post_event.upcoming_events_list.view_all"
  );

  constructor() {
    super(...arguments);

    this.appEvents.on("page:changed", this, this.updateEventsByMonth);
  }

  get shouldRender() {
    if (!this.categoryId) {
      return false;
    }

    const eventSettings =
      this.siteSettings.events_calendar_categories.split("|");

    return eventSettings.includes(this.categoryId.toString());
  }

  get categoryId() {
    return this.router.currentRoute.attributes?.category?.id;
  }

  get hasEmptyResponse() {
    return (
      !this.isLoading &&
      !this.hasError &&
      Object.keys(this.eventsByMonth).length === 0
    );
  }

  @action
  async updateEventsByMonth() {
    this.isLoading = true;
    this.hasError = false;

    try {
      const { events } = await ajax("/discourse-post-event/events", {
        data: { category_id: this.categoryId, limit: this.count },
      });

      this.eventsByMonth = this.groupByMonthAndDay(events);
    } catch {
      this.hasError = true;
    } finally {
      this.isLoading = false;
    }
  }

  @action
  formatMonth(month) {
    return moment(month, "YYYY-MM").format(this.monthFormat);
  }

  @action
  formatDate(month, day) {
    return moment(`${month}-${day}`, "YYYY-MM-DD").format(this.dateFormat);
  }

  @action
  formatTime({ starts_at, ends_at }) {
    return isNotFullDayEvent(moment(starts_at), moment(ends_at))
      ? moment(starts_at).format(this.timeFormat)
      : this.allDayLabel;
  }

  groupByMonthAndDay(data) {
    return data.reduce((result, item) => {
      const date = new Date(item.starts_at);
      const year = date.getFullYear();
      const month = date.getMonth() + 1;
      const day = date.getDate();

      const monthKey = `${year}-${month}`;

      result[monthKey] = result[monthKey] ?? {};
      result[monthKey][day] = result[monthKey][day] ?? [];

      result[monthKey][day].push(item);

      return result;
    }, {});
  }

  <template>
    {{#if this.shouldRender}}
      <div class="upcoming-events-list">
        <h3 class="upcoming-events-list__heading">
          {{this.title}}
        </h3>

        <div class="upcoming-events-list__container">
          <ConditionalLoadingSpinner @condition={{this.isLoading}} />

          {{#if this.hasEmptyResponse}}
            <div class="upcoming-events-list__empty-message">
              {{this.emptyMessage}}
            </div>
          {{/if}}

          {{#if this.hasError}}
            <div class="upcoming-events-list__error-message">
              {{this.errorMessage}}
            </div>
            <DButton
              @action={{this.updateEventsByMonth}}
              @label="discourse_calendar.discourse_post_event.upcoming_events_list.try_again"
              class="btn-link upcoming-events-list__try-again"
            />
          {{/if}}

          {{#unless this.isLoading}}
            {{#each-in this.eventsByMonth as |month monthData|}}
              {{#if this.monthFormat}}
                <h4 class="upcoming-events-list__formatted-month">
                  {{this.formatMonth month}}
                </h4>
              {{/if}}

              {{#each-in monthData as |day events|}}
                <div class="upcoming-events-list__day-section">
                  <div class="upcoming-events-list__formatted-day">
                    {{this.formatDate month day}}
                  </div>

                  {{#each events as |event|}}
                    <a
                      class="upcoming-events-list__event"
                      href={{event.post.url}}
                    >
                      <div class="upcoming-events-list__event-time">
                        {{this.formatTime event}}
                      </div>
                      <div class="upcoming-events-list__event-name">
                        {{or event.name event.post.topic.title}}
                      </div>
                    </a>
                  {{/each}}
                </div>
              {{/each-in}}
            {{/each-in}}
          {{/unless}}
        </div>

        <div class="upcoming-events-list__footer">
          <LinkTo @route="discourse-post-event-upcoming-events" class="upcoming-events-list__view-all">
            {{this.viewAllLabel}}
          </LinkTo>
        </div>
      </div>
    {{/if}}
  </template>
}
