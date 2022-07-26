import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Discourse Calendar - Holiday Flair", function (needs) {
  needs.user();
  needs.settings({ calendar_enabled: true });
  needs.site({
    users_on_holiday: ["foo", "eviltrout"],
  });

  needs.pretender((server, helper) => {
    server.get("/directory_items", () => {
      return helper.response({
        directory_items: [
          {
            id: 1,
            likes_received: 0,
            likes_given: 0,
            topics_entered: 0,
            topic_count: 0,
            post_count: 0,
            posts_read: 0,
            days_visited: 1,
            user: {
              id: 1,
              username: "foo",
              name: "Foo",
              avatar_template:
                "/letter_avatar_proxy/v4/letter/f/3be4f8/{size}.png",
            },
          },
          {
            id: 2,
            likes_received: 0,
            likes_given: 0,
            topics_entered: 0,
            topic_count: 0,
            post_count: 0,
            posts_read: 0,
            days_visited: 1,
            user: {
              id: 2,
              username: "bar",
              name: "Bar",
              avatar_template:
                "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
            },
          },
        ],
        meta: {
          last_updated_at: "2020-01-01T12:00:00.000Z",
          total_rows_directory_items: 2,
          load_more_directory_items:
            "/directory_items?order=likes_received&page=1&period=weekly",
        },
      });
    });
  });

  test("shows holiday emoji in directory", async function (assert) {
    await visit("/u");

    assert.ok(exists(".holiday-flair"));
    assert.ok(exists("div[data-username='foo'] .holiday-flair"));
    assert.ok(!exists("div[data-username='bar'] .holiday-flair"));
  });

  test("shows holiday emoji on mention", async function (assert) {
    await visit("/t/1-3-0beta9-no-rate-limit-popups/28830");
    assert.ok(exists(".mention.on-holiday img.on-holiday"));
    assert.strictEqual(
      query(".mention.on-holiday").innerText.trim(),
      "@eviltrout"
    );
  });
});
