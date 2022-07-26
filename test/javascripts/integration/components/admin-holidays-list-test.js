import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | admin-holidays-list",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("displaying a list of the provided holidays", {
      template: hbs`{{admin-holidays-list holidays=holidays}}`,

      beforeEach() {
        this.set("holidays", [
          { date: "2022-01-01", name: "New Year's Day" },
          { date: "2022-01-17", name: "Martin Luther King, Jr. Day" },
        ]);
      },

      async test(assert) {
        assert.strictEqual(
          query("table tbody tr:nth-child(1) td:nth-child(1)").innerText.trim(),
          "2022-01-01",
          "it displays the first holiday date"
        );
        assert.strictEqual(
          query("table tbody tr:nth-child(1) td:nth-child(2)").innerText.trim(),
          "New Year's Day",
          "it displays the first holiday name"
        );

        assert.strictEqual(
          query("table tbody tr:nth-child(2) td:nth-child(1)").innerText.trim(),
          "2022-01-17",
          "it displays the second holiday date"
        );
        assert.strictEqual(
          query("table tbody tr:nth-child(2) td:nth-child(2)").innerText.trim(),
          "Martin Luther King, Jr. Day",
          "it displays the second holiday name"
        );
      },
    });
  }
);
