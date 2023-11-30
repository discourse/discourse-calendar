import { visit, triggerEvent } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

acceptance("Discourse Calendar - Category Events Calendar", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    events_calendar_categories: "1",
    calendar_categories: "",
    map_events_to_color: JSON.stringify([
      {
        type: "tag",
        color: "rgb(231, 76, 60)",
        slug: "awesome-tag",
      },
      {
        type: "category",
        color: "rgb(140,24,193)",
        slug: "awesome-category",
      },
    ]),
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-post-event/events.json", () => {
      return helper.response({
        events: [
          {
            id: 67501,
            starts_at: moment()
              .tz("Asia/Calcutta")
              .add(1, "days")
              .format("YYYY-MM-DDT15:14:00.000Z"),
            ends_at: moment()
              .tz("Asia/Calcutta")
              .add(1, "days")
              .format("YYYY-MM-DDT16:14:00.000Z"),
            timezone: "Asia/Calcutta",
            post: {
              id: 67501,
              post_number: 1,
              url: "/t/this-is-an-event/18449/1",
              topic: {
                id: 18449,
                title: "This is an event",
                tags: ["awesome-tag"],
              },
            },
            name: "Awesome Event",
          },
          {
            id: 67502,
            starts_at: moment()
              .tz("Asia/Calcutta")
              .add(2, "days")
              .format("YYYY-MM-DDT15:14:00.000Z"),
            ends_at: moment()
              .tz("Asia/Calcutta")
              .add(2, "days")
              .format("YYYY-MM-DDT16:14:00.000Z"),
            timezone: "Asia/Calcutta",
            post: {
              id: 67502,
              post_number: 1,
              url: "/t/this-is-an-event/18450/1",
              topic: {
                id: 18450,
                title: "This is an event",
                category_slug: "awesome-category",
              },
            },
            name: "Awesome Event 2",
          },
        ],
      });
    });
  });

  test("events display the color configured in the map_events_to_color site setting", async (assert) => {
    await visit("/c/bug/1");

    assert
      .dom(".fc-event")
      .exists({ count: 2 }, "One event is displayed on the calendar");

    assert.dom(".fc-event[href='/t/-/18449/1']").hasStyle({
      "background-color": "rgb(231, 76, 60)",
    });

    assert.dom(".fc-event[href='/t/-/18450/1']").hasStyle({
      "background-color": "rgb(140, 24, 193)",
    });

  });

  test("shows event calendar on category page", async (assert) => {
    await visit("/c/bug/1");

    assert
      .dom("#category-events-calendar")
      .exists("Events calendar div exists.");
    assert.dom(".fc-view-container").exists("FullCalendar is loaded.");
  });

  test("uses current locale to display calendar weekday names", async (assert) => {
    I18n.locale = "pt_BR";

    await visit("/c/bug/1");

    assert.deepEqual(
      [...queryAll(".fc-day-header span")].map((el) => el.innerText),
      ["dom.", "seg.", "ter.", "qua.", "qui.", "sex.", "sáb."],
      "Week days are translated in the calendar header"
    );

    I18n.locale = "en";
  });
});
