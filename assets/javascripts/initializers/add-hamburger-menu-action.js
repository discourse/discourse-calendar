import { withPluginApi } from "discourse/lib/plugin-api";

function initializeHamburgerMenu(api) {
  api.decorateWidget("hamburger-menu:generalLinks", () => {
    return {
      icon: "calendar-day",
      route: "discourse-post-event-upcoming-events",
      label: "discourse_post_event.upcoming_events.title",
    };
  });
}

export default {
  name: "add-hamburger-menu-action",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (siteSettings.discourse_post_event_enabled) {
      withPluginApi("0.8.7", initializeHamburgerMenu);
    }
  },
};
