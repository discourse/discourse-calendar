import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | region-input", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("displaying the 'None' region option", {
    template: hbs`{{region-input allowNoneRegion=true}}`,

    beforeEach() {
      this.siteSettings.available_locales = JSON.stringify([
        { name: "English", value: "en" },
      ]);
    },

    async test(assert) {
      await selectKit().expand();

      assert.equal(
        query(
          ".region-input ul li.select-kit-row:first-child"
        ).innerText.trim(),
        "None",
        "it displays the 'None' option when allowNoneRegion is set to true"
      );
    },
  });

  componentTest("hiding the 'None' region option", {
    template: hbs`{{region-input allowNoneRegion=false}}`,

    beforeEach() {
      this.siteSettings.available_locales = JSON.stringify([
        { name: "English", value: "en" },
      ]);
    },

    async test(assert) {
      await selectKit().expand();

      assert.notEqual(
        query(
          ".region-input ul li.select-kit-row:first-child"
        ).innerText.trim(),
        "None",
        "it does not display the 'None' option when allowNoneRegion is set to false"
      );
    },
  });
});
