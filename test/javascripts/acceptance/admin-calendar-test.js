import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Admin - Calendar", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    available_locales: JSON.stringify([{ name: "English", value: "en" }]),
  });

  needs.pretender((server, helper) => {
    server.get("/admin/discourse-calendar/holiday-regions/ca/holidays", () => {
      return helper.response({
        holidays: [
          { date: "2022-01-01", name: "New Year's Day" },
          { date: "2022-04-15", name: "Good Friday" },
        ],
      });
    });
  });

  test("viewing holidays for a selected region", async (assert) => {
    const regions = selectKit(".region-input");

    await visit("/admin/plugins/calendar");
    await regions.expand();
    await regions.selectRowByValue("ca");

    assert.ok(
      query(".holidays-list").innerText.includes("New Year's Day"),
      "it displays holiday names"
    );
    assert.ok(
      query(".holidays-list").innerText.includes("Good Friday"),
      "it displays holiday names"
    );

    assert.ok(
      query(".holidays-list").innerText.includes("2022-01-01"),
      "it displays holiday dates"
    );
    assert.ok(
      query(".holidays-list").innerText.includes("2022-04-15"),
      "it displays holiday dates"
    );
  });
});
