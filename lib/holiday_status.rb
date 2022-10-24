# frozen_string_literal: true

module DiscourseCalendar
  class HolidayStatus
    EMOJI = 'desert_island'

    def self.is_holiday_status?(status)
      status.emoji == EMOJI && status.description == I18n.t("discourse_calendar.holiday_status.description")
    end
  end
end
