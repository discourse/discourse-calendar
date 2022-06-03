import { computed } from "@ember/object";
import { HOLIDAY_REGIONS } from "discourse/plugins/discourse-calendar/lib/regions";
import I18n from "I18n";
import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["timezone-input"],
  classNames: ["timezone-input", "region-input"],
  allowNoneRegion: false,

  selectKitOptions: {
    filterable: true,
    allowAny: false,
  },

  content: computed(function () {
    const localeNames = {};
    let regions = [];

    JSON.parse(this.siteSettings.available_locales).forEach((locale) => {
      localeNames[locale.value] = locale.name;
    });

    if (this.allowNoneRegion === true) {
      regions.push({
        name: I18n.t("discourse_calendar.region.none"),
        id: null,
      });
    }

    regions = regions.concat(
      HOLIDAY_REGIONS.map((region) => ({
        name: I18n.t(`discourse_calendar.region.names.${region}`),
        id: region,
      })).sort((a, b) => a.name.localeCompare(b.name))
    );
    return regions;
  }),
});
