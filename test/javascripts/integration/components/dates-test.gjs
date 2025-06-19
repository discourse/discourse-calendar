import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Dates from "../../discourse/components/discourse-post-event/dates";

module("Integration | Component | Dates", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const store = getOwner(this).lookup("service:store");

    this.user = store.createRecord("user", {
      username: "j.jaffeux",
      name: "joffrey",
      id: 321,
    });

    getOwner(this).unregister("service:current-user");
    getOwner(this).register("service:current-user", this.user, {
      instantiate: false,
    });

    this.basicEvent = class {
      @tracked endsAt;
      @tracked startsAt = new Date("2023-10-01T10:00:00Z");

      id = "123";
      recurrence = false;
      showLocalTime = false;
      timezone = "Asia/Singapore";
      isExpired = false;
    };
  });

  test("formats same day range dates and times", async function (assert) {
    const eventWithinDayRange = new (class extends this.basicEvent {
      @tracked endsAt = new Date("2023-10-01T11:00:00Z");
    })();

    await render(<template><Dates @event={{eventWithinDayRange}} /></template>);

    assert
      .dom(".event-dates")
      .hasText(
        "Sun, Oct 1, 2023 10:00 AM → 11:00 AM",
        "`endAt` should be formatted with localized time only"
      );
  });

  test("formats same week range dates and times", async function (assert) {
    const eventWithinWeekRange = new (class extends this.basicEvent {
      @tracked endsAt = new Date("2023-10-03T00:00:00Z");
    })();

    await render(
      <template><Dates @event={{eventWithinWeekRange}} /></template>
    );

    assert
      .dom(".event-dates")
      .hasText(
        "Sun, Oct 1, 2023 10:00 AM → Tue, Oct 3, 12:00 AM",
        "`endAt` should be formatted with localized weekday, date and time"
      );
  });

  test("formats different month range dates and times", async function (assert) {
    const eventWithinWeekRange = new (class extends this.basicEvent {
      @tracked endsAt = new Date("2024-11-01T10:00:00Z");
    })();

    await render(
      <template><Dates @event={{eventWithinWeekRange}} /></template>
    );

    assert
      .dom(".event-dates")
      .hasText(
        "Sun, Oct 1, 2023 10:00 AM → Fri, Nov 1, 2024 10:00 AM",
        "`endAt` should be formatted with localized weekday, date and time"
      );
  });

  test("formats different year range dates and times", async function (assert) {
    const eventWithinWeekRange = new (class extends this.basicEvent {
      @tracked endsAt = new Date("2024-10-01T10:00:00Z");
    })();

    await render(
      <template><Dates @event={{eventWithinWeekRange}} /></template>
    );

    assert
      .dom(".event-dates")
      .hasText(
        "Sun, Oct 1, 2023 10:00 AM → Tue, Oct 1, 2024 10:00 AM",
        "`endAt` should be formatted with localized weekday, date and time"
      );
  });
});
