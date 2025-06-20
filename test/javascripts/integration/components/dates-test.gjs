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
        endsAt: "2025-10-10",
      },
      endsSameMonth: {
        ...starts,
        endsAt: "2025-10-20",
      },
      endsDiffMonth: {
        ...starts,
        endsAt: "2025-11-06",
      },
      endsDiffYear: {
        ...starts,
        endsAt: "2026-01-06",
      },
    },
  };

  module("dates without time", function () {
    test("formats same day range dates and times", async function (assert) {
      const testState = new (class {
        // @tracked endsAt = new Date("2025-10-01T11:00:00Z");
        @tracked event = events.currentYear.starts;
      })();

      await render(<template><Dates @event={{testState.event}} /></template>);

      assert
        .dom(".event-dates")
        .hasText(
          "Mon, Oct 6",
          "`startAt` should not render the current year, and not show any time"
        );

      testState.event = events.currentYear.endsSameWeek;
      await settled();
      assert
        .dom(".event-dates")
        .hasText(
          "Mon, Oct 6 → Fri, Oct 10",
          "`startAt`, `endAt` should not render the current year, and not show any time"
        );
    });
  });

  test("formats same week range dates and times", async function (assert) {
    const eventWithinWeekRange = new (class extends this.basicEvent {
      @tracked endsAt = "2025-10-03T00:00:00Z";
      // @tracked endsAt = new Date("2025-10-03T00:00:00Z");
    })();

    await render(
      <template><Dates @event={{eventWithinWeekRange}} /></template>
    );

    assert
      .dom(".event-dates")
      .hasText(
        "Wed, Oct 1 10:00 AM → Fri, Oct 3",
        "`endAt` should be formatted with localized weekday, date and time"
      );
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
