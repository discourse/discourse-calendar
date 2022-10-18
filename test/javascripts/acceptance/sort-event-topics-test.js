import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import Site from "discourse/models/site";

acceptance("Calendar - Disable sorting headers", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    disable_resorting_on_categories_enabled: true,
  });

  test("visiting a category page", async function (assert) {
    const site = Site.current();
    site.categories[15].custom_fields = { disable_topic_resorting: true };

    await visit("/c/bug");
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(
      exists(".topic-list .topic-list-data"),
      "The headers were rendered"
    );
    assert.ok(!exists(".topic-list .sortable"), "The headers are not sortable");
  });
});
