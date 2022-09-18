import discourseComputed from "discourse-common/utils/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
	name: "disable-sort",
	initialize() {
		withPluginApi("0.8", (api) => {
			api.modifyClass('component:topic-list',{

				@discourseComputed("category")
				sortable(category) {
					var disableSort  = true;
					if(category && category.custom_fields) {
						disableSort = !!category.custom_fields["disable_topic_resorting"];
					}
					return !!this.changeSort && !disableSort;
				},

			})
		})
	},
};
