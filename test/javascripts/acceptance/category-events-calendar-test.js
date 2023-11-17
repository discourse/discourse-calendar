import { visit } from "@ember/test-helpers";
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
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-post-event/events.json", () => {
      return helper.response({
        events: [
          {
            id: 67501,
            starts_at: "2022-04-25T15:14:00.000Z",
            ends_at: "2022-04-30T16:14:00.000Z",
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
          },
        ],
      });
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
