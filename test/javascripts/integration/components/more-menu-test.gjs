import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { apiInitializer } from "discourse/lib/api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import MoreMenu from "../../discourse/components/discourse-post-event/more-menu";

module("Integration | Component | MoreMenu", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const store = getOwner(this).lookup("service:store");

    this.user = store.createRecord("user", {
      username: "j.jaffeux",
      name: "joffrey",
      id: 321,
    });

    getOwner(this).unregister("service:current-user");
    getOwner(this).register("service:current-user", this.user, {
      instantiate: false,
    });
  });

  test("value transformer works", async function (assert) {
    apiInitializer("1.34.0", (api) => {
      api.registerValueTransformer(
        "discourse-calendar-should-show-participants",
        () => {
          return true; // by default it should not show to unauthenticated users
        }
      );
    });
    await render(<template>
      <MoreMenu @event={{hash isExpired=false creator=this.user}} />
    </template>);
    await click(".discourse-post-event-more-menu-trigger");
    assert.dom(".show-all-participants").exists();
  });
});
