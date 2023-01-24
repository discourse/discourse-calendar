import { emojiUrlFor } from "discourse/lib/text";

export default {
  shouldRender(args, context) {
    return (
      context.siteSettings.calendar_enabled &&
      context.site.users_on_holiday &&
      context.site.users_on_holiday.includes(args.user.username)
    );
  },

  setupComponent(args, component) {
    const holidayEmojiName =
      this.get("siteSettings.holiday_status_emoji") || "date";
    component.setProperties({
      holidayEmojiName: `:${holidayEmojiName}:`,
      holidayEmoji: emojiUrlFor(holidayEmojiName),
    });
  },
};
