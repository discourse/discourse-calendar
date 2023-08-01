import { action } from "@ember/object";
import { TIME_ZONE_TO_REGION } from "../../lib/regions";

export default {
  setupComponent(args, component) {
    component.setProperties({
      @action
      onChange(value) {
        this.model.set("custom_fields.holidays-region", value);
      },

      @action
      useCurrentRegion() {
        this.model.set(
          "custom_fields.holidays-region",
          TIME_ZONE_TO_REGION[moment.tz.guess()] || "us"
        );
      },
    });
  },

  shouldRender(args, component) {
    return component.siteSettings.calendar_enabled;
  },
};
