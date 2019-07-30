# frozen_string_literal: true

module DiscourseCalendar
  class CalendarValidator
    def initialize(post)
      @post = post
    end

    def validate_calendar
      extracted_calendars = DiscourseCalendar::Calendar::extract(@post)

      return false if extracted_calendars.count == 0
      return false if more_than_one_calendar(extracted_calendars.count)
      return false if !calendar_in_first_post(@post.is_first_post?)

      extracted_calendars.first
    end

    private

    def calendar_in_first_post(is_first_post)
      if !is_first_post
        @post.errors.add(:base, I18n.t("discourse_calendar.calendar_must_be_in_first_post"))
        return false
      end

      true
    end

    def more_than_one_calendar(calendars_count)
      if calendars_count > 1
        @post.errors.add(:base, I18n.t("discourse_calendar.more_than_one_calendar"))
        return true
      end

      false
    end
  end
end
