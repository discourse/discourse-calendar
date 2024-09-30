import I18n from "I18n";

export function getCurrentBcp47Locale() {
  return I18n.currentLocale().replace("_", "-").toLowerCase();
}

export function getCalendarButtonsText() {
  return {
    today: I18n.t("discourse_calendar.toolbar_button.today"),
    month: I18n.t("discourse_calendar.toolbar_button.month"),
    week: I18n.t("discourse_calendar.toolbar_button.week"),
    day: I18n.t("discourse_calendar.toolbar_button.day"),
    list: I18n.t("discourse_calendar.toolbar_button.list"),
  };
}
