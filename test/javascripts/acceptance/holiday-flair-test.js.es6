import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Discourse Calendar - Holiday Flair", function (needs) {
  needs.user();
  needs.settings({ calendar_enabled: true });
  needs.site({
    users_on_holiday: ["foo"],
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

  test("shows holiday emoji in directory", async (assert) => {
    await visit("/u");
    assert.equal(find(".holiday-flair").length, 1);
    assert.equal(find("div[data-username='foo'] .holiday-flair").length, 1);
    assert.equal(find("div[data-username='bar'] .holiday-flair").length, 0);
  });
});
