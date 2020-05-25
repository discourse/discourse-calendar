import { withPluginApi } from "discourse/lib/plugin-api";
import { iconHTML } from "discourse-common/lib/icon-library";

export default {
  name: "add-holiday-flair",

  initialize() {
    withPluginApi("0.8", api => {
      const usernames = api.container.lookup("site:main").users_on_holiday;

      if (usernames && usernames.length > 0) {
        api.decorateCooked(
          el => {
            const $el = $(el);

            usernames.forEach(username => {
              const href = `${Discourse.BaseUri}/u/${username}`;

              $el
                .find(`a.mention[href="${href}"]:not(.on-holiday)`)
                .append(iconHTML("calendar-alt"))
                .addClass("on-holiday");
            });
          },
          { id: "discourse-calendar-holiday-flair" }
        );

        api.addPosterIcon(cfs => {
          if (cfs.on_holiday) {
            return {
              emoji: "desert_island",
              className: "holiday",
              title: I18n.t("discourse_calendar.on_holiday")
            };
          }
        });
      }
    });
  }
};
