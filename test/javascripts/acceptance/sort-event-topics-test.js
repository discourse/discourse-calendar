import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import CategoryFixtures from "discourse/tests/fixtures/category-fixtures";

acceptance("Calendar - Disable sorting headers", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    const categoryResponse = cloneJSON(CategoryFixtures["/c/1/show.json"]);
    categoryResponse.category.custom_fields["disable_topic_resorting"] = true;
    server.get("/c/1/show.json", () => helper.response(categoryResponse));
  });

  test("visiting a category page", async function (assert) {
    await visit("/c/bug");
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(
      exists(".topic-list .topic-list-data"),
      "The headers were rendered"
    );
    assert.ok(!exists(".topic-list .sortable"), "The headers are not sortable");
  });
});
