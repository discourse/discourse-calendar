import discourseComputed from "discourse/lib/decorators";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "disable-sort",

  initialize(container) {
    withPluginApi("0.8", (api) => {
      // TODO: cvx - remove after the glimmer topic list transition
      withSilencedDeprecations("discourse.hbr-topic-list-overrides", () => {
        api.modifyClass(
          "component:topic-list",
          (Superclass) =>
            class extends Superclass {
              @discourseComputed(
                "category",
                "siteSettings.disable_resorting_on_categories_enabled"
              )
              sortable(category, disable_resorting_on_categories_enabled) {
                const disableSort =
                  disable_resorting_on_categories_enabled &&
                  !!category?.custom_fields?.disable_topic_resorting;

                return super.sortable && !disableSort;
              }
            }
        );
      });

      api.registerValueTransformer(
        "topic-list-header-sortable-column",
        ({ value, context }) => {
          if (!value) {
            return value;
          }

          const siteSettings = container.lookup("service:site-settings");
          return !(
            siteSettings.disable_resorting_on_categories_enabled &&
            context.category?.custom_fields?.disable_topic_resorting
          );
        }
      );
    });
  },
};
