import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { i18n } from "discourse-i18n";
import AdminHolidaysList from "discourse/plugins/discourse-calendar/discourse/components/admin-holidays-list";
import RegionInput from "discourse/plugins/discourse-calendar/discourse/components/region-input";

export default RouteTemplate(
  <template>
    <h3>
      {{i18n "discourse_calendar.holidays.header_title"}}
    </h3>

    <RegionInput
      @value={{@controller.selectedRegion}}
      @onChange={{action "getHolidays"}}
    />

    <p class="desc">
      {{i18n "discourse_calendar.holidays.pick_region_description"}}
      <br /><br />
      {{i18n "discourse_calendar.holidays.disabled_holidays_description"}}
    </p>

    <ConditionalLoadingSpinner @condition={{@controller.loading}} />

    {{#if @controller.model.holidays}}
      <AdminHolidaysList
        @holidays={{@controller.model.holidays}}
        @region_code={{@controller.selectedRegion}}
      />
    {{/if}}
  </template>
);
