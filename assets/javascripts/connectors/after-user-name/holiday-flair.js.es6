import { emojiUrlFor } from "discourse/lib/text";

const HOLIDAY_EMOJI_NAME = "desert_island";

export default {
  shouldRender(args, context) {
    return (
      context.siteSettings.calendar_enabled &&
      context.site.users_on_holiday.includes(args.user.username)
    );
  },

  setupComponent(args, component) {
    component.setProperties({
      holidayEmojiName: `:${HOLIDAY_EMOJI_NAME}:`,
      holidayEmoji: emojiUrlFor(HOLIDAY_EMOJI_NAME)
    });
  }
};
