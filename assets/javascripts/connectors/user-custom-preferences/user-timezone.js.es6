export default {
  setupComponent(args, component) {
    const { currentUser } = component;
    const user = args.model;

    let instructions;

    // only show the instructions when browsing your own profile
    if (currentUser && currentUser.id === user.id) {
      instructions = I18n.t("discourse_calendar.timezone.instructions", {
        timezone: moment.tz.guess()
      });
    }

    component.setProperties({
      instructions,
      allTimezones: moment.tz.names(),
      userTimezone: user.custom_fields.timezone
    });

    component.addObserver("userTimezone", () => {
      user.set("custom_fields.timezone", component.get("userTimezone"));
    });
  },

  shouldRender(args, component) {
    return component.siteSettings.calendar_enabled;
  }
};
