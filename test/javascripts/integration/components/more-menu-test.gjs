import { hash } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import MoreMenu from "../../discourse/components/discourse-post-event/more-menu";

module("Integration | Component | MoreMenu", function (hooks) {
  setupRenderingTest(hooks);

  test("value transformer works", async function (assert) {

    withPluginApi("1.34.0", (api) => {
      api.registerValueTransformer(
        "discourse-calendar-should-show-participants",
        () => {
          return true; // by default it should not show to unauthenticated users
        }
      );
    });

    await render(<template>
      <MoreMenu @event={{hash isExpired=false}} />
    </template>);

    await click(".discourse-post-event-more-menu-trigger");
    assert.dom(".show-all-participants").exists();
  });
});
