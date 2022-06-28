import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Admin - Discourse Calendar - Holidays", function (needs) {
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

    server.post("/admin/discourse-calendar/holidays/disable", () => {
      return helper.response({ success: "OK" });
    });

    server.delete("/admin/discourse-calendar/holidays/enable", () => {
      return helper.response({ success: "OK" });
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

  test("disabling and enabling a holiday", async (assert) => {
    const regions = selectKit(".region-input");

    await visit("/admin/plugins/calendar");
    await regions.expand();
    await regions.selectRowByValue("ca");

    await click("table tr:first-child button");
    assert.ok(
      query("table tr.disabled:first-child"),
      "after clicking the disable button, it adds a .disabled CSS class"
    );

    await click("table tr.disabled:first-child button");
    assert.ok(
      query("table tr:first-child"),
      "after clicking the enable button, it removes the .disabled CSS class"
    );
  });
});
