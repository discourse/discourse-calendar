module DiscourseCalendar
  class CalendarUpdater
    def self.update(post)
      calendar = post.calendar || {}

      post.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD] = calendar.delete("type") || "dynamic"

      unless post.custom_fields[DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD].present?
        post.calendar_details = {}
      end

      post.save_custom_fields
    end
  end
end
