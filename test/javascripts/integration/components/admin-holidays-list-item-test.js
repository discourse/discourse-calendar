import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | admin-holidays-list-item",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`{{admin-holidays-list-item
      holiday=holiday
      region_code=region_code
      isHolidayDisabled=holiday.disabled
    }}`;

    componentTest(
      "when a holiday is disabled, it displays an enable button and adds a disabled CSS class",
      {
        template,

        beforeEach() {
          this.set("holiday", {
            date: "2022-01-01",
            name: "New Year's Day",
            disabled: true,
          });
          this.set("region_code", "sg");
        },

        async test(assert) {
          assert.equal(
            query("button").innerText.trim(),
            "Enable",
            "it displays an enable button"
          );
          assert.ok(query(".disabled"), "it adds a 'disabled' CSS class");
        },
      }
    );

    componentTest(
      "when a holiday is enabled, it displays a disable button and does not add a disabled CSS class",
      {
        template,

        beforeEach() {
          this.set("holiday", {
            date: "2022-01-01",
            name: "New Year's Day",
            disabled: false,
          });
          this.set("region_code", "au");
        },

        async test(assert) {
          assert.equal(
            query("button").innerText.trim(),
            "Disable",
            "it displays a disable button"
          );
          assert.notOk(
            query(".disabled"),
            "it does not add a 'disabled' CSS class"
          );
        },
      }
    );
  }
);
