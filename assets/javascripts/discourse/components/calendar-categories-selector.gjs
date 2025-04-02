import { tracked } from "@glimmer/tracking";
import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import Category from "discourse/models/category";
import MultiSelectComponent from "select-kit/components/multi-select";
import { pluginApiIdentifiers } from "select-kit/components/select-kit";

@classNames("event-categories-selector")
@pluginApiIdentifiers(["event-categories-selector"])
export default class CalendarCategoriesSelector extends MultiSelectComponent {
  @tracked events = null;

  @computed("events.[]")
  get content() {
    return Category.findByIds(this.events.map((e) => e.categoryId))
      .map((c) => {
        let name = c.name;
        if (c.parent_category_id) {
          const parentCategory = Category.findById(c.parent_category_id);
          name = `${parentCategory.name} / ${name}`;
        }
        return {
          id: c.id,
          name,
        };
      })
      .sort((a, b) => a.name.localeCompare(b.name));
  }
}
