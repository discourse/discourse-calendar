# frozen_string_literal: true

module DiscourseCalendar
  class HolidayStatus
    EMOJI = 'desert_island'

    def self.set!(user, ends_at)
      status = user.user_status

      if status.blank? ||
        status.expired? ||
        (is_holiday_status?(status) && status.ends_at != ends_at)

        user.set_status!(
          I18n.t("discourse_calendar.holiday_status.description"),
          EMOJI,
          ends_at)
      end
    end

    def self.clear!(user)
      if user.user_status && is_holiday_status?(user.user_status)
        user.clear_status!
      end
    end

    private

    def self.is_holiday_status?(status)
      status.emoji == EMOJI && status.description == I18n.t("discourse_calendar.holiday_status.description")
    end
  end
end
