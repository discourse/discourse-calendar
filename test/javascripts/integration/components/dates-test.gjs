import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import Dates from "../../discourse/components/discourse-post-event/dates";

module("Integration | Component | Dates", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.basicEvent = class {
      @tracked endsAt;
      @tracked startsAt = new Date("2025-10-01T10:00:00Z");

      id = "123";
      recurrence = false;
      showLocalTime = false;
      timezone = "Asia/Singapore";
      isExpired = false;
    };

    this.clock = fakeTime("2025-11-01T00:00:00Z", "UTC", true);
  });

  hooks.afterEach(function () {
    this.clock?.restore();
  });

  const starts = {
    startsAt: "2025-10-06T00:00:00Z",
    timezone: "UTC",
  };
  const events = {
    currentYear: {
      starts,
      endsSameDay: {
        ...starts,
        endsAt: "2025-10-06T01:00:00Z",
      },
      endsSameWeek: {
        ...starts,
        endsAt: "2025-10-10T00:00:00Z",
      },
      endsSameMonth: {
        ...starts,
        endsAt: "2025-10-20T00:00:00Z",
      },
      endsDiffMonth: {
        ...starts,
        endsAt: "2025-11-06T00:00:00Z",
      },
      endsDiffYear: {
        ...starts,
        endsAt: "2026-01-06T00:00:00Z",
      },
    },
  };

  module("dates without time", function () {
    test("formats start date", async function (assert) {
      await render(
        <template><Dates @event={{events.currentYear.starts}} /></template>
      );

      assert
        .dom(".event-dates")
        .hasText(
          "Mon, Oct 6",
          "`startsAt` should not show current year and time"
        );
    });

    test("formats same day range", async function (assert) {
      await render(
        <template><Dates @event={{events.currentYear.endsSameDay}} /></template>
      );

      assert
        .dom(".event-dates")
        .hasText(
          "Mon, Oct 6 12:00 AM → 1:00 AM",
          "`endsAt` should show time only"
        );
    });

    test("formats same week range", async function (assert) {
      await render(
        <template><Dates @event={{events.currentYear.endsSameWeek}} /></template>
      );

      assert
        .dom(".event-dates")
        .hasText(
          "Mon, Oct 6 → Fri, Oct 10",
          "`endAt` should be formatted with weekday, month and date"
        );
    });

    test("formats same month range", async function (assert) {
      await render(
        <template><Dates @event={{events.currentYear.endsSameMonth}} /></template>
      );

      assert
        .dom(".event-dates")
        .hasText(
          "Mon, Oct 6 → Mon, Oct 20",
          "`endAt` should be formatted with weekday, month and date"
        );
    });

    test("formats different months range", async function (assert) {
      await render(
        <template><Dates @event={{events.currentYear.endsDiffMonth}} /></template>
      );

      assert
        .dom(".event-dates")
        .hasText(
          "Mon, Oct 6 → Thu, Nov 6",
          "`endAt` should be formatted with weekday, month and date"
        );
    });
  });

  test("formats different month range dates and times", async function (assert) {
    const eventWithinWeekRange = new (class extends this.basicEvent {
      @tracked endsAt = new Date("2025-11-01T10:00:00Z");
    })();

    await render(
      <template><Dates @event={{eventWithinWeekRange}} /></template>
    );

    assert
      .dom(".event-dates")
      .hasText(
        "Wed, Oct 1 10:00 AM → Sat, Nov 1 10:00 AM",
        "`endAt` should be formatted with localized weekday, date and time"
      );
  });

  test("formats different year range dates and times", async function (assert) {
    const eventWithinWeekRange = new (class extends this.basicEvent {
      @tracked endsAt = new Date("2026-10-01T10:00:00Z");
    })();

    await render(
      <template><Dates @event={{eventWithinWeekRange}} /></template>
    );

    assert
      .dom(".event-dates")
      .hasText(
        "Wed, Oct 1 10:00 AM → Thu, Oct 1, 2026 10:00 AM",
        "`endAt` should be formatted with localized weekday, date and time"
      );
  });
});
