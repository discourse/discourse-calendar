import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { cloneJSON } from "discourse-common/lib/object";
import sinon from "sinon";

acceptance("Discourse Calendar - Event Title Decorator", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.get("/latest.json", () => {
      const topicList = cloneJSON(discoveryFixtures["/latest.json"]);
      topicList.topic_list.topics[0].event_starts_at = "2022-01-10 19:00:00";
      topicList.topic_list.topics[0].event_ends_at = "2022-01-10 20:00:00";

      return helper.response(topicList);
    });
  });

  test("shows event date with attributes in topic list", async (assert) => {
    sinon.stub(moment.tz, "guess");
    moment.tz.guess.returns("UTC");
    moment.tz.setDefault("UTC");

    await visit("/latest");

    const firstTopic = query(".topic-list-item:first-child .raw-topic-link");
    assert.dom(".event-date.past", firstTopic).exists();
    assert.dom(".event-date", firstTopic).hasAttribute("data-starts_at");
    assert.dom(".event-date", firstTopic).hasAttribute("data-ends_at");
    assert
      .dom(".event-date", firstTopic)
      .hasAttribute(
        "title",
        "January 10, 2022 7:00 PM → January 10, 2022 8:00 PM"
      );
  });
});
