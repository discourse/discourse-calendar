import { acceptance, fakeTime } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";

const topicResponse = {
  post_stream: {
    posts: [
      {
        id: 375,
        name: null,
        username: "jan",
        avatar_template: "/letter_avatar_proxy/v4/letter/j/ce7236/{size}.png",
        created_at: "2023-09-08T16:50:07.638Z",
        raw: '[calendar fullDay="false"] [/calendar]',
        cooked:
          '<div class="discourse-calendar-wrap"><div class="discourse-calendar-header"><h2 class="discourse-calendar-title"></h2><span class="discourse-calendar-timezone-wrap"></span></div><div class="calendar" data-calendar-type="dynamic" data-calendar-default-timezone="undefined" data-calendar-full-day="false"><p> </p></div></div>',
        post_number: 1,
        post_type: 1,
        updated_at: "2023-09-08T16:50:07.638Z",
        reply_count: 0,
        reply_to_post_number: null,
        quote_count: 0,
        incoming_link_count: 2,
        reads: 1,
        readers_count: 0,
        score: 10.2,
        yours: true,
        topic_id: 252,
        topic_slug: "awesome-calendar",
        display_username: null,
        primary_group_name: null,
        flair_name: null,
        flair_url: null,
        flair_bg_color: null,
        flair_color: null,
        flair_group_id: null,
        version: 1,
        can_edit: true,
        can_delete: false,
        can_recover: false,
        can_see_hidden_post: true,
        can_wiki: true,
        read: true,
        user_title: null,
        bookmarked: false,
        actions_summary: [
          { id: 3, can_act: true },
          { id: 4, can_act: true },
          { id: 8, can_act: true },
          { id: 7, can_act: true },
        ],
        moderator: false,
        admin: true,
        staff: true,
        user_id: 1,
        hidden: false,
        trust_level: 1,
        deleted_at: null,
        user_deleted: false,
        edit_reason: null,
        can_view_edit_history: true,
        wiki: false,
        reviewable_id: 0,
        reviewable_score_count: 0,
        reviewable_score_pending_count: 0,
        mentioned_users: [],
        calendar_details: [
          {
            type: "standalone",
            post_number: 2,
            message: "Event 1",
            from: "2023-09-08T00:00:00.000Z",
            to: "2023-09-08T00:00:00.000Z",
            username: "jan",
            recurring: null,
            post_url: "/t/-/252/2",
            timezone: "America/Cordoba",
          },
          {
            type: "standalone",
            post_number: 5,
            message: "Event 2",
            from: "2023-09-20T00:00:00.000Z",
            to: "2023-09-20T00:00:00.000Z",
            username: "jan",
            recurring: null,
            post_url: "/t/-/252/5",
            timezone: "Europe/Lisbon",
          },
        ],
      },
    ],
  },
  details: {},
};

function getEventByText(text) {
  const events = [...document.querySelectorAll(".fc-day-grid-event")].filter(
    (event) => event.textContent.includes(text)
  );
  if (!events.length) {
    return;
  }
  return events.length === 1 ? events[0] : events;
}

acceptance("Discourse Calendar - Topic Calendar Events", function (needs) {
  let clock;

  needs.hooks.beforeEach(() => {
    clock = fakeTime("2023-09-10T00:00:00", "Europe/Lisbon", true);
  });

  needs.hooks.afterEach(() => {
    clock?.restore();
  });

  needs.settings({
    calendar_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.get("/t/252.json", () => {
      return helper.response(topicResponse);
    });
  });

  test("renders calendar events with fullDay='false'", async (assert) => {
    await visit("/t/252");

    assert.ok(getEventByText("Event 1"));
    assert.ok(getEventByText("Event 2"));
  });
});
