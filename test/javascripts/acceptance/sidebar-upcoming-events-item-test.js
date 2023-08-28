import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Discourse Calendar - hamburger action shown", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    sidebar_show_upcoming_events: true,
    navigation_menu: "legacy",
  });

  test("upcoming events hamburger action shown", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown");
    assert.ok(exists(".widget-link[title='Upcoming events']"));
  });
});

acceptance("Discourse Calendar - hamburger action hidden", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    sidebar_show_upcoming_events: false,
    navigation_menu: "legacy",
  });

  test("upcoming events hamburger action hidden", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown");
    assert.notOk(exists(".widget-link[title='Upcoming events']"));
  });
});

acceptance("Discourse Calendar - sidebar link shown", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    sidebar_show_upcoming_events: true,
    navigation_menu: "sidebar",
  });

  test("upcoming events sidebar section link shown", async function (assert) {
    await visit("/");
    await click(".sidebar-more-section-links-details-summary");
    assert.ok(
      exists(".sidebar-section-link[data-link-name='upcoming-events']")
    );
  });
});

acceptance("Discourse Calendar - sidebar link hidden", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    sidebar_show_upcoming_events: false,
    navigation_menu: "sidebar",
  });

  test("upcoming events sidebar section link hidden", async function (assert) {
    await visit("/");
    await click(".sidebar-more-section-links-details-summary");
    assert.notOk(
      exists(".sidebar-section-link[data-link-name='upcoming-events']")
    );
  });
});
