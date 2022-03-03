import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";
import { iconHTML } from "discourse-common/lib/icon-library";
import { cancel, later } from "@ember/runloop";
import getURL from "discourse-common/lib/get-url";

function applyFlairOnMention(element, username) {
  if (!element) {
    return;
  }

  const href = getURL(`/u/${username.toLowerCase()}`);
  const mentions = element.querySelectorAll(`a.mention[href="${href}"]`);

  mentions.forEach((mention) => {
    if (!mention.querySelector(".d-icon-calendar-alt")) {
      mention.insertAdjacentHTML("beforeend", iconHTML("calendar-alt"));
    }
    mention.classList.add("on-holiday");
  });
}

export default {
  name: "add-holiday-flair",

  initialize() {
    withPluginApi("0.10.1", (api) => {
      const usernames = api.container.lookup("site:main").users_on_holiday;

      if (usernames && usernames.length > 0) {
        api.addUsernameSelectorDecorator((username) => {
          if (usernames.includes(username)) {
            return `<span class="on-holiday">${iconHTML(
              "calendar-alt"
            )}</span>`;
          }
        });
      }
    });

    withPluginApi("0.8", (api) => {
      const usernames = api.container.lookup("site:main").users_on_holiday;

      if (usernames?.length > 0) {
        let flairHandler;

        api.cleanupStream(() => cancel(flairHandler));

        if (api.decorateChatMessage) {
          api.decorateChatMessage((message) => {
            usernames.forEach((username) =>
              applyFlairOnMention(message, username)
            );
          });
        }

        api.decorateCookedElement(
          (element, helper) => {
            if (helper) {
              // decorating a post
              usernames.forEach((username) =>
                applyFlairOnMention(element, username)
              );
            } else {
              // decorating preview
              cancel(flairHandler);
              flairHandler = later(
                () =>
                  usernames.forEach((username) =>
                    applyFlairOnMention(element, username)
                  ),
                1000
              );
            }
          },
          { id: "discourse-calendar-holiday-flair" }
        );

        api.addPosterIcon((cfs) => {
          if (cfs.on_holiday) {
            return {
              emoji: "desert_island",
              className: "holiday",
              title: I18n.t("discourse_calendar.on_holiday"),
            };
          }
        });
      }
    });
  },
};
