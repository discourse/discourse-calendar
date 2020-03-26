import { withPluginApi } from "discourse/lib/plugin-api";

function initializeHamburgerMenu(api) {
  api.decorateWidget("hamburger-menu:generalLinks", () => {
    return {
      icon: "calendar-day",
      route: "upcoming-events",
      label: "upcoming_events.title"
    };
  });
}

export default {
  name: "add-hamburger-menu-action",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.post_event_enabled) {
      withPluginApi("0.8.7", initializeHamburgerMenu);
    }
  }
};
