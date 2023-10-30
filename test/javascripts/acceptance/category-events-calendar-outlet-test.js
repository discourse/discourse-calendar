import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

const eventsPretender = (server, helper) => {
  server.get("/discourse-post-event/events.json", () => {
    return helper.response({
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
};

acceptance(
  "Discourse Calendar - Category Events Calendar Outlet None",
  function (needs) {
    needs.user();
    needs.settings({
      calendar_enabled: true,
      discourse_post_event_enabled: true,
      events_calendar_categories: "1",
      calendar_categories: "",
      calendar_categories_outlet: "none",
    });

    needs.pretender(eventsPretender);

    test("don't display calendars if outlet option is none", async (assert) => {
      await visit("/c/bug/1");

      assert.notOk(
        exists("#category-events-calendar"),
        "Category Events calendar div does not exist"
      );

      assert.notOk(
        exists(".category-calendar"),
        "Category calendar div does not exist."
      );
    });
  }
);

acceptance(
  "Discourse Calendar - Category Events Calendar Outlet Container Top",
  function (needs) {
    needs.user();
    needs.settings({
      calendar_enabled: true,
      discourse_post_event_enabled: true,
      events_calendar_categories: "1",
      calendar_categories: "",
      calendar_categories_outlet: "discovery-list-container-top",
    });

    needs.pretender(eventsPretender);

    test("display the specific calendar for the discovery-list-container-top outlet", async (assert) => {
      await visit("/c/bug/1");

      assert.ok(
        exists("#category-events-calendar"),
        "Category Events calendar div exists"
      );

      assert.notOk(
        exists(".category-calendar"),
        "Category calendar div does not exist."
      );
    });
  }
);

acceptance(
  "Discourse Calendar - Category Events Calendar Outlet Container Before Topic List",
  function (needs) {
    needs.user();
    needs.settings({
      calendar_enabled: true,
      discourse_post_event_enabled: true,
      events_calendar_categories: "1",
      calendar_categories: "",
      calendar_categories_outlet: "before-topic-list-body",
    });

    needs.pretender(eventsPretender);

    test("display the specific calendar for before-topic-list-body outlet", async (assert) => {
      await visit("/c/bug/1");

      assert.notOk(
        exists("#category-events-calendar"),
        "Category Events calendar div does not exist"
      );

      assert.ok(exists(".category-calendar"), "Category calendar div exists.");
    });
  }
);
