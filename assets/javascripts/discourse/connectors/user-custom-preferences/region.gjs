import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import RegionInput from "../../components/region-input";
import { TIME_ZONE_TO_REGION } from "../../lib/regions";

export default class Region extends Component {
  static shouldRender(args, component) {
    return component.siteSettings.calendar_enabled;
  }

  @service siteSettings;

  @action
  onChange(value) {
    this.args.model.set("custom_fields.holidays-region", value);
  }

  @action
  useCurrentRegion() {
    this.args.model.set(
      "custom_fields.holidays-region",
      TIME_ZONE_TO_REGION[moment.tz.guess()] || "us"
    );
  }

  <template>
    <div class="control-group">
      <label class="control-label">
        {{i18n "discourse_calendar.region.title"}}
      </label>

      <div class="controls">
        <RegionInput
          @value={{@model.custom_fields.holidays-region}}
          @allowNoneRegion={{true}}
          @onChange={{this.onChange}}
        />
      </div>

      <DButton
        @icon="globe"
        @label="discourse_calendar.region.use_current_region"
        @action={{this.useCurrentRegion}}
      />
    </div>
  </template>
}
