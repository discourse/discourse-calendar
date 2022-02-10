import I18n from "I18n";
import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("discourse-group-timezones-header", {
  tagName: "div.group-timezones-header",

  transform(attrs) {
    return {
      title: I18n.t("group_timezones.group_availability", {
        group: attrs.group,
      }),
    };
  },

  template: hbs`
    {{attach
      widget="discourse-group-timezones-time-traveler"
      attrs=(hash
        id=attrs.id
        localTimeOffset=attrs.localTimeOffset
      )
    }}
    <span class="title">
      {{transformed.title}}
    </span>
    {{attach widget="discourse-group-timezones-filter"}}
  `,
});
