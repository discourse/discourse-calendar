import { hash } from "@ember/helper";
import Service from "@ember/service";
import { render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  exists,
  fakeTime,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";
import UpcomingEventsList, {
  DEFAULT_DATE_FORMAT,
  DEFAULT_MONTH_FORMAT,
  DEFAULT_TIME_FORMAT,
} from "../../discourse/components/upcoming-events-list";

class RouterStub extends Service {
  currentRoute = { attributes: { category: { id: 1 } } };
}

const today = "2100-02-01T08:00:00";
const tomorrowAllDay = "2100-02-02T00:00:00";
const nextMonth = "2100-03-02T08:00:00";

module("Integration | Component | upcoming-events-list", function (hooks) {
  setupRenderingTest(hooks);

  let clock;

  hooks.beforeEach(function () {
    this.owner.unregister("service:router");
    this.owner.register("service:router", RouterStub);

    this.siteSettings.events_calendar_categories = "1";

    this.appEvents = this.container.lookup("service:appEvents");

    clock = fakeTime(today, null, true);
  });

  hooks.afterEach(() => {
    clock.restore();
  });

  test("empty state message", async function (assert) {
    pretender.get("/discourse-post-event/events", () => {
      return response({ events: [] });
    });

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url : "/" });

    assert.strictEqual(
      query(".upcoming-events-list__heading").innerText,
      I18n.t("discourse_post_event.upcoming_events_list.title"),
      "it displays the title"
    );

    await waitFor(".loading-container .spinner", { count: 0 });

    assert.strictEqual(
      query(".upcoming-events-list__empty-message").innerText,
      I18n.t("discourse_post_event.upcoming_events_list.empty"),
      "it displays the empty list message"
    );
  });

  test("with events, standard formats", async function (assert) {
    pretender.get("/discourse-post-event/events", twoEventsResponseHandler);

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url : "/" });

    assert.strictEqual(
      query(".upcoming-events-list__heading").innerText,
      I18n.t("discourse_post_event.upcoming_events_list.title"),
      "it displays the title"
    );

    await waitFor(".loading-container .spinner", { count: 0 });

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__formatted-month")].map(
        (el) => el.innerText
      ),
      [
        moment(tomorrowAllDay).format(DEFAULT_MONTH_FORMAT),
        moment(nextMonth).format(DEFAULT_MONTH_FORMAT),
      ],
      "it displays the formatted month"
    );

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__formatted-day")].map(
        (el) => el.innerText
      ),
      [
        moment(tomorrowAllDay).format(DEFAULT_DATE_FORMAT),
        moment(nextMonth).format(DEFAULT_DATE_FORMAT),
      ],
      "it displays the formatted day"
    );

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-time")].map(
        (el) => el.innerText
      ),
      [
        I18n.t("discourse_post_event.upcoming_events_list.all_day"),
        moment(nextMonth).format(DEFAULT_TIME_FORMAT),
      ],
      "it displays the formatted time"
    );

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-name")].map(
        (el) => el.innerText
      ),
      ["Awesome Event", "Another Awesome Event"],
      "it displays the event name"
    );
  });

  test("with events, overriden formats", async function (assert) {
    pretender.get("/discourse-post-event/events", twoEventsResponseHandler);

    await render(<template>
      <UpcomingEventsList
        @params={{hash monthFormat="" dateFormat="L" timeFormat="LLL"}}
      />
    </template>);

    this.appEvents.trigger("page:changed", { url : "/" });

    assert.strictEqual(
      query(".upcoming-events-list__heading").innerText,
      I18n.t("discourse_post_event.upcoming_events_list.title"),
      "it displays the title"
    );

    await waitFor(".loading-container .spinner", { count: 0 });

    assert.ok(
      !exists(".upcoming-events-list__formatted-month"),
      "it omits the formatted month when empty"
    );

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__formatted-day")].map(
        (el) => el.innerText
      ),
      [moment(tomorrowAllDay).format("L"), moment(nextMonth).format("L")],
      "it displays the formatted day"
    );

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-time")].map(
        (el) => el.innerText
      ),
      [
        I18n.t("discourse_post_event.upcoming_events_list.all_day"),
        moment(nextMonth).format("LLL"),
      ],
      "it displays the formatted time"
    );

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-name")].map(
        (el) => el.innerText
      ),
      ["Awesome Event", "Another Awesome Event"],
      "it displays the event name"
    );
  });

  test("with an error response", async function (assert) {
    pretender.get("/discourse-post-event/events", () => {
      return response(500, {});
    });

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url : "/" });

    assert.strictEqual(
      query(".upcoming-events-list__heading").innerText,
      I18n.t("discourse_post_event.upcoming_events_list.title"),
      "it displays the title"
    );

    await waitFor(".loading-container .spinner", { count: 0 });

    assert.strictEqual(
      query(".upcoming-events-list__error-message").innerText,
      I18n.t("discourse_post_event.upcoming_events_list.error"),
      "it displays the error message"
    );

    assert.strictEqual(
      query(".upcoming-events-list__try-again").innerText,
      I18n.t("discourse_post_event.upcoming_events_list.try_again"),
      "it displays the try again button"
    );
  });
});

function twoEventsResponseHandler() {
  return response({
    events: [
      {
        id: 67501,
        creator: {
          id: 1500588,
          username: "foobar",
          name: null,
          avatar_template: "/user_avatar/localhost/foobar/{size}/1913_2.png",
          assign_icon: "user-plus",
          assign_path: "/u/foobar/activity/assigned",
        },
        sample_invitees: [],
        watching_invitee: null,
        starts_at: tomorrowAllDay,
        ends_at: null,
        timezone: "Asia/Calcutta",
        stats: {
          going: 0,
          interested: 0,
          not_going: 0,
          invited: 0,
        },
        status: "public",
        raw_invitees: ["trust_level_0"],
        post: {
          id: 67501,
          post_number: 1,
          url: "/t/this-is-an-event/18449/1",
          topic: {
            id: 18449,
            title: "This is an event",
          },
        },
        name: "Awesome Event",
        can_act_on_discourse_post_event: true,
        can_update_attendance: true,
        is_expired: false,
        is_ongoing: true,
        should_display_invitees: false,
        url: null,
        custom_fields: {},
        is_public: true,
        is_private: false,
        is_standalone: false,
        reminders: [],
        recurrence: null,
        category_id: 1,
      },
      {
        id: 67502,
        creator: {
          id: 1500588,
          username: "foobar",
          name: null,
          avatar_template: "/user_avatar/localhost/foobar/{size}/1913_2.png",
          assign_icon: "user-plus",
          assign_path: "/u/foobar/activity/assigned",
        },
        sample_invitees: [],
        watching_invitee: null,
        starts_at: nextMonth,
        ends_at: null,
        timezone: "Asia/Calcutta",
        stats: {
          going: 0,
          interested: 0,
          not_going: 0,
          invited: 0,
        },
        status: "public",
        raw_invitees: ["trust_level_0"],
        post: {
          id: 67501,
          post_number: 1,
          url: "/t/this-is-an-event-2/18450/1",
          topic: {
            id: 18449,
            title: "This is an event 2",
          },
        },
        name: "Another Awesome Event",
        can_act_on_discourse_post_event: true,
        can_update_attendance: true,
        is_expired: false,
        is_ongoing: true,
        should_display_invitees: false,
        url: null,
        custom_fields: {},
        is_public: true,
        is_private: false,
        is_standalone: false,
        reminders: [],
        recurrence: null,
        category_id: 2,
      },
    ],
  });
}
