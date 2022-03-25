import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { cloneJSON } from "discourse-common/lib/object";

const topicList = cloneJSON(discoveryFixtures["/latest.json"]);

function latestResponse() {
  topicList.topic_list.topics[0].event_starts_at = "2022-01-10 19:00:00";
  topicList.topic_list.topics[0].event_ends_at = "2022-01-10 20:00:00";
  return topicList;
}

acceptance("Discourse Calendar - Event Title Decorator", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.get("/latest.json", () => {
      return helper.response(latestResponse());
    });
  });

  test("shows event date with attributes in topic list", async (assert) => {
    await visit("/latest");

    const firstTopic = query(".topic-list-item:first-child .raw-topic-link");
    assert.ok(firstTopic.querySelector(".event-date.past"));
    assert.ok(
      firstTopic.querySelector(".event-date").getAttribute("data-starts_at")
    );
    assert.ok(
      firstTopic.querySelector(".event-date").getAttribute("data-ends_at")
    );
    assert.ok(
      firstTopic
        .querySelector(".event-date")
        .getAttribute("title")
        .startsWith("January 10, 2022")
    );
  });
});
