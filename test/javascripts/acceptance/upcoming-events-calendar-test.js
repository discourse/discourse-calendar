import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { tomorrow } from "discourse/lib/time-utils";
import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Discourse Calendar - Upcoming Events Calendar", function (needs) {
  needs.site({
    categories: [
      {
        id: 1,
        name: "Category 1",
        slug: "caetgory-1",
        color: "0f78be",
      },
      {
        id: 2,
        name: "Category 2",
        slug: "category-2",
        color: "be0a0a",
      },
    ],
  });
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    events_calendar_categories: "1",
    calendar_categories: "",
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-post-event/events", () => {
      return helper.response({
        events: [
          {
            id: 67501,
            starts_at: tomorrow(),
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
            starts_at: tomorrow(),
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
        ],
      });
    });
  });

  test("shows upcoming events calendar", async (assert) => {
    await visit("/upcoming-events");

    assert.ok(
      exists("#upcoming-events-calendar"),
      "Upcoming Events calendar is shown."
    );

    assert.ok(exists(".fc-view-container"), "FullCalendar is loaded.");
  });

  test("upcoming events category colors", async (assert) => {
    await visit("/upcoming-events");

    assert.strictEqual(
      query(".fc-row tr:first-child .fc-event").style.backgroundColor,
      "rgb(190, 10, 10)",
      "Event item uses the proper color from category 1"
    );

    assert.strictEqual(
      query(".fc-row tr:nth-child(2) .fc-event").style.backgroundColor,
      "rgb(15, 120, 190)",
      "Event item uses the proper color from category 2"
    );
  });
});
