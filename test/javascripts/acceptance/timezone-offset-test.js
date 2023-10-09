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
        raw: '[calendar weekends=true tzPicker="true" fullDay="true" showAddToCalendar="false" defaultTimezone="Europe/Lisbon"] [/calendar]',
        cooked:
          '\u003cdiv class="discourse-calendar-wrap"\u003e\n\u003cdiv class="discourse-calendar-header"\u003e\n\u003ch2 class="discourse-calendar-title"\u003e\u003c/h2\u003e\n\u003cspan class="discourse-calendar-timezone-wrap"\u003e\n\u003cselect class="discourse-calendar-timezone-picker"\u003e\u003c/select\u003e\n\u003c/span\u003e\n\u003c/div\u003e\n\u003cdiv class="calendar" data-calendar-type="dynamic" data-calendar-default-timezone="Europe/Lisbon" data-weekends="true" data-calendar-show-add-to-calendar="false" data-calendar-full-day="true"\u003e\u003c/div\u003e\n\u003c/div\u003e',
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
            message: "Cordoba",
            from: "2023-09-14T00:00:00.000Z",
            to: "2023-09-14T00:00:00.000Z",
            username: "jan",
            recurring: null,
            post_url: "/t/-/252/2",
            timezone: "America/Cordoba",
          },
          {
            type: "standalone",
            post_number: 4,
            message: "Moscow",
            from: "2023-09-17T00:00:00.000Z",
            to: "2023-09-18T00:00:00.000Z",
            username: "jan",
            recurring: null,
            post_url: "/t/-/252/3",
            timezone: "Europe/Moscow",
          },
          {
            type: "standalone",
            post_number: 3,
            message: "Tokyo",
            from: "2023-09-20T00:00:00.000Z",
            to: "2023-09-21T00:00:00.000Z",
            username: "jan",
            recurring: null,
            post_url: "/t/-/252/4",
            timezone: "Asia/Tokyo",
          },
          {
            type: "standalone",
            post_number: 5,
            message: "Lisbon",
            from: "2023-09-28T00:00:00.000Z",
            to: "2023-09-28T00:00:00.000Z",
            username: "jan",
            recurring: null,
            post_url: "/t/-/252/5",
            timezone: "Europe/Lisbon",
          },
          {
            type: "grouped",
            from: "2023-09-04T05:00:00.000Z",
            name: "Labor Day",
            users: [
              {
                username: "gmt-5_user",
                timezone: "America/Chicago",
              },
              {
                username: "gmt-6_user",
                timezone: "America/Denver",
              },
              {
                username: "gmt-7_user",
                timezone: "America/Los_Angeles",
              },
            ],
          },
        ],
      },
    ],
  },
  timeline_lookup: [[1, 0]],
  tags: [],
  tags_descriptions: {},
  id: 252,
  title: "Awesome Calendar",
  fancy_title: "Awesome Calendar",
  posts_count: 5,
  created_at: "2023-09-08T16:50:07.371Z",
  views: 1,
  reply_count: 0,
  like_count: 0,
  last_posted_at: "2023-09-08T16:50:52.936Z",
  visible: true,
  closed: false,
  archived: false,
  has_summary: false,
  archetype: "regular",
  slug: "awesome-calendar",
  category_id: 5,
  word_count: 56,
  deleted_at: null,
  user_id: 1,
  featured_link: null,
  pinned_globally: false,
  pinned_at: null,
  pinned_until: null,
  image_url: null,
  slow_mode_seconds: 0,
  draft: null,
  draft_key: "topic_252",
  draft_sequence: 9,
  posted: true,
  unpinned: null,
  pinned: false,
  current_post_number: 1,
  highest_post_number: 4,
  last_read_post_number: 4,
  last_read_post_id: 378,
  deleted_by: null,
  has_deleted: false,
  actions_summary: [
    { id: 4, count: 0, hidden: false, can_act: true },
    { id: 8, count: 0, hidden: false, can_act: true },
    { id: 7, count: 0, hidden: false, can_act: true },
  ],
  chunk_size: 20,
  bookmarked: false,
  bookmarks: [],
  topic_timer: null,
  message_bus_last_id: 16,
  participant_count: 1,
  show_read_indicator: false,
  thumbnails: null,
  slow_mode_enabled_until: null,
  summarizable: false,
  details: {
    can_edit: true,
    notification_level: 3,
    notifications_reason_id: 1,
    can_move_posts: true,
    can_delete: true,
    can_remove_allowed_users: true,
    can_invite_to: true,
    can_invite_via_email: true,
    can_create_post: true,
    can_reply_as_new_topic: true,
    can_flag_topic: true,
    can_convert_topic: true,
    can_review_topic: true,
    can_close_topic: true,
    can_archive_topic: true,
    can_split_merge_topic: true,
    can_edit_staff_notes: true,
    can_toggle_topic_visibility: true,
    can_pin_unpin_topic: true,
    can_moderate_category: true,
    can_remove_self_id: 1,
    participants: [
      {
        id: 1,
        username: "jan",
        name: null,
        avatar_template: "/letter_avatar_proxy/v4/letter/j/ce7236/{size}.png",
        post_count: 4,
        primary_group_name: null,
        flair_name: null,
        flair_url: null,
        flair_color: null,
        flair_bg_color: null,
        flair_group_id: null,
        admin: true,
        trust_level: 1,
      },
    ],
    created_by: {
      id: 1,
      username: "jan",
      name: null,
      avatar_template: "/letter_avatar_proxy/v4/letter/j/ce7236/{size}.png",
    },
    last_poster: {
      id: 1,
      username: "jan",
      name: null,
      avatar_template: "/letter_avatar_proxy/v4/letter/j/ce7236/{size}.png",
    },
  },
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

function getRoundedPct(marginString) {
  return Math.round(marginString.match(/(\d+(\.\d+)?)%/)[1]);
}

function setupClock(needs) {
  let clock;

  needs.hooks.beforeEach(() => {
    clock = fakeTime("2023-09-10T00:00:00", "Australia/Brisbane", true);
  });

  needs.hooks.afterEach(() => {
    clock?.restore();
  });
}

acceptance("Discourse Calendar - Timezone Offset", function (needs) {
  setupClock(needs);

  needs.settings({
    calendar_enabled: true,
    enable_timezone_offset_for_calendar_events: true,
    default_timezone_offset_user_option: true,
  });

  needs.pretender((server, helper) => {
    server.get("/t/252.json", () => {
      return helper.response(topicResponse);
    });
  });

  test("doesn't apply an offset for events in the same timezone", async (assert) => {
    await visit("/t/252");

    const eventElement = getEventByText("Lisbon");

    assert.notOk(eventElement.style.marginLeft);
    assert.notOk(eventElement.style.marginRight);
  });

  test("applies the correct offset for events that extend into the next day", async (assert) => {
    await visit("/t/252");

    const eventElement = getEventByText("Cordoba");

    assert.strictEqual(getRoundedPct(eventElement.style.marginLeft), 8); // ( ( 1 - (-3) ) / 24 ) * 50%
    assert.strictEqual(getRoundedPct(eventElement.style.marginRight), 42); // ( ( 24 - ( 1 - (-3) ) ) / 24 ) * 50%
  });

  test("applies the correct offset for events that start on the previous day", async (assert) => {
    await visit("/t/252");

    const eventElement = getEventByText("Tokyo");

    assert.strictEqual(getRoundedPct(eventElement.style.marginLeft), 22); // ( ( 24 - ( 9 - 1 ) ) / 24 ) * 33.33%
    assert.strictEqual(getRoundedPct(eventElement.style.marginRight), 11); // ( ( 9 - 1 ) / 24 ) * 33.33%
  });

  test("applies the correct offset for multiline events", async (assert) => {
    await visit("/t/252");

    const eventElement = getEventByText("Moscow");

    assert.strictEqual(getRoundedPct(eventElement[0].style.marginLeft), 46); // ( ( 24 - ( 1 - (-1) ) ) / 24 ) * 50%
    assert.notOk(eventElement[0].style.marginRight);

    assert.notOk(eventElement[1].style.marginLeft);
    assert.strictEqual(getRoundedPct(eventElement[1].style.marginRight), 8); // ( ( 1 - (-1) ) / 24 ) * 100%
  });
});

acceptance("Discourse Calendar - Splitted Grouped Events", function (needs) {
  setupClock(needs);

  needs.settings({
    calendar_enabled: true,
    enable_timezone_offset_for_calendar_events: true,
    default_timezone_offset_user_option: true,
    split_grouped_events_by_timezone_threshold: 0,
  });

  needs.pretender((server, helper) => {
    server.get("/t/252.json", () => {
      return helper.response(topicResponse);
    });
  });

  test("splits holidays events by timezone", async (assert) => {
    await visit("/t/252");

    const eventElement = document.querySelectorAll(
      ".fc-day-grid-event.grouped-event"
    );
    assert.ok(eventElement.length === 3);

    assert.strictEqual(getRoundedPct(eventElement[0].style.marginLeft), 13); // ( ( 1 - (-5) ) / 24 ) * 50%
    assert.strictEqual(getRoundedPct(eventElement[0].style.marginRight), 38); // ( ( 24 - ( 1 - (-5) ) ) / 24 ) * 50%

    assert.strictEqual(getRoundedPct(eventElement[1].style.marginLeft), 15); // ( ( 1 - (-6) ) / 24 ) * 50%
    assert.strictEqual(getRoundedPct(eventElement[1].style.marginRight), 35); // ( ( 24 - ( 1 - (-6) ) ) / 24 ) * 50%

    assert.strictEqual(getRoundedPct(eventElement[2].style.marginLeft), 17); // ( ( 1 - (-7) ) / 24 ) * 50%
    assert.strictEqual(getRoundedPct(eventElement[2].style.marginRight), 33); // ( ( 24 - ( 1 - (-7) ) ) / 24 ) * 50%
  });
});

acceptance("Discourse Calendar - Grouped Events", function (needs) {
  setupClock(needs);

  needs.settings({
    calendar_enabled: true,
    enable_timezone_offset_for_calendar_events: true,
    default_timezone_offset_user_option: true,
    split_grouped_events_by_timezone_threshold: 2,
  });

  needs.pretender((server, helper) => {
    server.get("/t/252.json", () => {
      return helper.response(topicResponse);
    });
  });

  test("groups holidays events according to threshold", async (assert) => {
    await visit("/t/252");

    const eventElement = document.querySelectorAll(
      ".fc-day-grid-event.grouped-event"
    );
    assert.ok(eventElement.length === 1);

    assert.strictEqual(getRoundedPct(eventElement[0].style.marginLeft), 15); // ( ( 1 - (-6) ) / 24 ) * 50%
    assert.strictEqual(getRoundedPct(eventElement[0].style.marginRight), 35); // ( ( 24 - ( 1 - (-6) ) ) / 24 ) * 50%
  });
});
