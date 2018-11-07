import { withPluginApi } from "discourse/lib/plugin-api";
import { iconHTML } from "discourse-common/lib/icon-library";

function customBool(field) {
  if (field) {
    return Array.isArray(field) ? field.some(x => x === "t") : field === "t";
  }
  return false;
}

export default {
  name: "add-holiday-flair",
  initialize() {
    withPluginApi("0.1", api => {
      const usersOnHoliday = Discourse.Site.current().users_on_holiday;
      api.decorateCooked(el => {
        if (!usersOnHoliday) {
          return;
        }

        usersOnHoliday.forEach(username => {
          $(el)
            .find(`a.mention[href="/u/${username}"]`)
            .not(".on-holiday")
            .append(iconHTML("calendar"))
            .addClass("on-holiday");
        });
      });

      api.addPosterIcon(cfs => {
        const onHoliday = customBool(cfs.on_holiday);
        if (!onHoliday) {
          return;
        }

        return {
          emoji: "desert_island",
          className: "holiday",
          title: "on holiday"
        };
      });
    });
  }
};
