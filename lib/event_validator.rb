module DiscourseCalendar
  class EventValidator
    def initialize(post)
      @post = post
      @calendar = post&.topic&.first_post&.custom_fields
    end

    def validate_event
      dates_count = DiscourseCalendar::Event::count(@post)
      calendar_type = @calendar[DiscourseCalendar::CALENDAR_CUSTOM_FIELD] || "dynamic"

      if calendar_type == "dynamic"
        return false if has_too_many_dates?(dates_count)
      end

      if calendar_type == "static"
        return false if dates_count > 0
      end

      dates_count > 0
    end

    private

    def has_too_many_dates?(dates_count)
      if dates_count > 2
        @post.errors.add(:base, I18n.t("discourse_calendar.more_than_two_dates"))
        return true
      end

      false
    end
  end
end
