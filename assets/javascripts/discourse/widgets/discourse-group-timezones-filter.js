import I18n from "I18n";
import { createWidget } from "discourse/widgets/widget";
import { throttle } from "@ember/runloop";

export default createWidget("discourse-group-timezones-filter", {
  tagName: "input.group-timezones-filter",

  input(event) {
    this.changeFilterThrottler(event.target.value);
  },

  changeFilterThrottler(filter) {
    throttle(
      this,
      function () {
        this.sendWidgetAction("onChangeFilter", filter);
      },
      100
    );
  },

  buildAttributes() {
    return {
      type: "text",
      placeholder: I18n.t("group_timezones.search"),
    };
  },
});
