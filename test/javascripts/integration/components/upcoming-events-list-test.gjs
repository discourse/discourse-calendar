import { hash } from "@ember/helper";
import Service from "@ember/service";
import sinon from "sinon";
import { getOwner } from "@ember/owner";
import { click, currentURL, render, waitFor } from "@ember/test-helpers";
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
  currentRouteName = "discovery.latest";
  on() {}
  off() {}
}

const today = "2100-02-01T08:00:00";
const tomorrowAllDay = "2100-02-02T00:00:00";
const nextMonth = "2100-03-02T08:00:00";
const nextWeek = "2100-02-09T08:00:00";

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

    this.appEvents.trigger("page:changed", { url: "/" });

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

    this.appEvents.trigger("page:changed", { url: "/" });

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

    assert.ok(
      exists(".upcoming-events-list__view-all"),
      "it displays the view-all link"
    );
  });

  test("with multi-day events, standard formats", async function (assert) {
    pretender.get("/discourse-post-event/events", multiDayEventResponseHandler);

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    await waitFor(".loading-container .spinner", { count: 0 });

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-name")].map(
        (el) => el.innerText
      ),
      [
        "Awesome Multiday Event",
        "Awesome Multiday Event",
        "Awesome Multiday Event",
        "Awesome Multiday Event",
        "Awesome Multiday Event",
        "Awesome Multiday Event",
        "Awesome Multiday Event",
        "Awesome Multiday Event",
      ],

      "it displays the multiday event on all scheduled dates"
    );
  });

  test("with events, overridden titles", async function (assert) {
    const router = getOwner(this).lookup("service:router");
    sinon.stub(router, "currentURL").value("/program-pillars");

    this.siteSettings.map_events_title =
      '[{"category_slug": "announcements", "custom_title": "Upcoming Announcements"}]';

    await render(<template><UpcomingEventsList /></template>);
    this.appEvents.trigger("page:changed", { url: "/c/announcements" });

    assert.strictEqual(
      // query below returns null
      query(".upcoming-events-list__heading").innerText,
      "Upcoming Announcements",
      "it sets 'Upcoming Announcements' as the title in 'c/announcements'"
    );

    // this.args.params.categorySlug = "events";
    // assert.equal(
    //   component.title(),
    //   "Upcoming Cool Events",
    //   "it sets 'Upcoming Cool Events' as the title in 'c/events'"
    // );
    // this.args.params.categorySlug = "unknown";
    // assert.equal(
    //   component.title(),
    //   "Upcoming Events",
    //   "it returns the default value for title when otherwise not specified"
    // );
  });

  // in pair got UI working, QUnit test difficult because we need to set a page category and this is just component -- in system spec we ran into the issue with not having/loading the theme component
  // try QUnit one more time to see if i can get the cat working

  test("with events, view-all navigation", async function (assert) {
    pretender.get("/discourse-post-event/events", twoEventsResponseHandler);

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    await waitFor(".loading-container .spinner", { count: 0 });

    assert.strictEqual(
      query(".upcoming-events-list__view-all").innerText,
      I18n.t("discourse_post_event.upcoming_events_list.view_all"),
      "it displays the view-all link"
    );

    await click(".upcoming-events-list__view-all");

    assert.strictEqual(
      currentURL(),
      "/upcoming-events",
      "view-all link navigates to the upcoming-events page"
    );
  });

  test("with events, overridden formats", async function (assert) {
    pretender.get("/discourse-post-event/events", twoEventsResponseHandler);

    await render(<template>
      <UpcomingEventsList
        @params={{hash monthFormat="" dateFormat="L" timeFormat="LLL"}}
      />
    </template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    assert.strictEqual(
      query(".upcoming-events-list__heading").innerText,
      I18n.t("discourse_post_event.upcoming_events_list.title"),
      "it displays the title"
    );

    await waitFor(".loading-container .spinner", { count: 0 });

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

  test("with events, omitted formats", async function (assert) {
    pretender.get("/discourse-post-event/events", twoEventsResponseHandler);
    await render(<template>
      <UpcomingEventsList @params={{hash monthFormat="" timeFormat=""}} />
    </template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    assert
      .dom(".upcoming-events-list__heading")
      .hasText(
        I18n.t("discourse_post_event.upcoming_events_list.title"),
        "it displays the title"
      );

    await waitFor(".loading-container .spinner", { count: 0 });

    assert
      .dom(".upcoming-events-list__formatted-month")
      .doesNotExist("it omits the formatted month when empty");

    assert
      .dom(".upcoming-events-list__formatted-time")
      .doesNotExist("it omits the formatted time when empty");
  });

  test("with an error response", async function (assert) {
    pretender.get("/discourse-post-event/events", () => {
      return response(500, {});
    });

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url: "/" });

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

  test("with events, overridden count parameter", async function (assert) {
    pretender.get("/discourse-post-event/events", twoEventsResponseHandler);

    await render(<template>
      <UpcomingEventsList @params={{hash count=1}} />
    </template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    assert.strictEqual(
      query(".upcoming-events-list__heading").innerText,
      I18n.t("discourse_post_event.upcoming_events_list.title"),
      "it displays the title"
    );

    await waitFor(".loading-container .spinner", { count: 0 });

    assert.strictEqual(
      queryAll(".upcoming-events-list__event").length,
      1,
      "it limits the resulting items to the count parameter"
    );

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-name")].map(
        (el) => el.innerText
      ),
      ["Awesome Event"],
      "it displays the event name"
    );
  });

  test("with events, overridden upcomingDays parameter", async function (assert) {
    pretender.get("/discourse-post-event/events", twoEventsResponseHandler);

    await render(<template>
      <UpcomingEventsList @params={{hash upcomingDays=1}} />
    </template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    await waitFor(".loading-container .spinner", { count: 0 });

    assert.strictEqual(
      queryAll(".upcoming-events-list__event").length,
      1,
      "it limits the results to started_at before the provided parameter"
    );

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-name")].map(
        (el) => el.innerText
      ),
      ["Awesome Event"],
      "it displays the event name"
    );
  });
});

function twoEventsResponseHandler({ queryParams }) {
  let events = [
    {
      id: 67501,
      starts_at: tomorrowAllDay,
      ends_at: null,
      timezone: "Asia/Calcutta",
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
      category_id: 1,
    },
    {
      id: 67502,
      starts_at: nextMonth,
      ends_at: null,
      timezone: "Asia/Calcutta",
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
      category_id: 2,
    },
  ];

  if (queryParams.limit) {
    events.splice(queryParams.limit);
  }

  if (queryParams.before) {
    events = events.filter((event) => {
      return moment(event.starts_at).isBefore(queryParams.before);
    });
  }

  return response({ events });
}

function multiDayEventResponseHandler({ queryParams }) {
  let events = [
    {
      id: 67503,
      starts_at: tomorrowAllDay,
      ends_at: nextWeek,
      timezone: "Asia/Calcutta",
      post: {
        id: 67501,
        post_number: 1,
        url: "/t/this-is-an-event/18451/1",
        topic: {
          id: 18449,
          title: "This is a multiday event",
        },
      },
      name: "Awesome Multiday Event",
      category_id: 1,
    },
  ];

  if (queryParams.limit) {
    events.splice(queryParams.limit);
  }

  if (queryParams.before) {
    events = events.filter((event) => {
      return moment(event.starts_at).isBefore(queryParams.before);
    });
  }

  return response({ events });
}
