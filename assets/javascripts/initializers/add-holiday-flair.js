import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";
import { cancel } from "@ember/runloop";
import getURL from "discourse-common/lib/get-url";
import { emojiUnescape } from "discourse/lib/text";
import discourseLater from "discourse-common/lib/later";

function applyFlairOnMention(element, username) {
  if (!element) {
    return;
  }

  const href = getURL(`/u/${username.toLowerCase()}`);
  const mentions = element.querySelectorAll(`a.mention[href="${href}"]`);

  mentions.forEach((mention) => {
    if (!mention.querySelector(".on-holiday")) {
      mention.insertAdjacentHTML(
        "beforeend",
        emojiUnescape(":desert_island:", { class: "on-holiday" })
      );
    }
    mention.classList.add("on-holiday");
  });
}

export default {
  name: "add-holiday-flair",

  initialize() {
    withPluginApi("0.10.1", (api) => {
      const usernames = api.container.lookup("service:site").users_on_holiday;

      if (usernames && usernames.length > 0) {
        api.addUsernameSelectorDecorator((username) => {
          if (usernames.includes(username)) {
            return `<span class="on-holiday">${emojiUnescape(
              ":desert_island:",
              { class: "on-holiday" }
            )}</span>`;
          }
        });
      }
    });

    withPluginApi("0.8", (api) => {
      const usernames = api.container.lookup("service:site").users_on_holiday;

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
              flairHandler = discourseLater(
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
