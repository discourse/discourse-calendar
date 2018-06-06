module DiscourseSimpleCalendar
  class CalendarUpdater
    def self.update(post)
      details = post.calendar_details || {}

      post.custom_fields[DiscourseSimpleCalendar::CALENDAR_CUSTOM_FIELD] = details.delete("type") || "dynamic"

      unless post.custom_fields[DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD].present?
        post.custom_fields[DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD] = {}
      end

      post.save_custom_fields
    end
  end
end
