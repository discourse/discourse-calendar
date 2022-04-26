import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

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
            creator: {
              id: 1500588,
              username: "foobar",
              name: null,
              avatar_template:
                "/user_avatar/localhost/foobar/{size}/1913_2.png",
              assign_icon: "user-plus",
              assign_path: "/u/foobar/activity/assigned",
            },
            sample_invitees: [],
            watching_invitee: null,
            starts_at: "2022-04-25T15:14:00.000Z",
            ends_at: "2022-04-30T16:14:00.000Z",
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
            is_ongoing: false,
            should_display_invitees: false,
            url: null,
            custom_fields: {},
            is_public: true,
            is_private: false,
            is_standalone: false,
            reminders: [],
            recurrence: null,
          },
        ],
      });
    });
  });

  test("shows event calendar on category page", async (assert) => {
    await visit("/c/bug/1");

    assert.ok(
      exists("#category-events-calendar"),
      "Events calendar div exists."
    );
    assert.strictEqual(
      query(".fc-event-container .fc-content .fc-title").innerText,
      "Awesome Event",
      "Calendar has event name."
    );
  });
});
