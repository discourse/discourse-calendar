import discourseComputed from "discourse-common/utils/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "disable-sort",
  initialize() {
    withPluginApi("0.8", (api) => {
      api.modifyClass("component:topic-list", {
        pluginId: "discourse-calendar",

        @discourseComputed(
          "category",
          "siteSettings.disable_resorting_on_categories_enabled"
        )
        sortable(category, disable_resorting_on_categories_enabled) {
          let disableSort = false;
          if (
            disable_resorting_on_categories_enabled &&
            category?.custom_fields
          ) {
            disableSort = !!category.custom_fields["disable_topic_resorting"];
          }
          return !!this.changeSort && !disableSort;
        },
      });
    });
  },
};
