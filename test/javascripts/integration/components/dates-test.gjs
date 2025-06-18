import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
// import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Dates from "../../discourse/components/discourse-post-event/dates";

module("Integration | Component | Dates", function (hooks) {
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

  test("formats dates", async function (assert) {
    // withPluginApi("1.34.0", (api) => {
    //   api.registerValueTransformer(
    //     "discourse-calendar-event-more-menu-should-show-participants",
    //     () => {
    //       return true; // by default it should show to canActOnDiscoursePostEvent users
    //     }
    //   );
    // });

    // const store = getOwner(this).lookup("service:store");
    // const creator = store.createRecord("user", {
    //   username: "gabriel",
    //   name: "gabriel",
    //   id: 322,
    // });

    const startsAt = new Date("2023-10-01T10:00:00Z");
    const endsAt = new Date("2023-10-01T11:00:00Z");

    await render(
      <template>
        <Dates
          @event={{hash
            id="123"
            recurrence=false
            showLocalTime=false
            timezone="Asia/Singapore"
            isExpired=false
            endsAt=endsAt
            startsAt=startsAt
          }}
        />
      </template>
    );

    assert.dom(".event-dates").hasText("October 1, 2023 10:00 AM → 11:00 AM");
  });
});
