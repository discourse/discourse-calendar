# frozen_string_literal: true

module DiscourseCalendar
  class CalendarUpdater
    def self.update(post)
      calendar = post.calendar || {}

      previous_type = post.custom_fields[CALENDAR_CUSTOM_FIELD].dup

      post.custom_fields[CALENDAR_CUSTOM_FIELD] = calendar.delete("type") || "dynamic"

      if previous_type != post.custom_fields[CALENDAR_CUSTOM_FIELD] || post.calendar_details.blank?
        post.calendar_details = {}
      end

      post.save_custom_fields
    end
  end
end
