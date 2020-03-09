# frozen_string_literal: true

module Jobs
  class ::DiscourseCalendar::EnsureConsistency < ::Jobs::Scheduled
    every 12.hours

    def execute(args)
      return unless SiteSetting.calendar_enabled
      return unless topic_id = SiteSetting.holiday_calendar_topic_id

      CalendarEvent.includes(:post).where(topic_id: topic_id).find_each do |event|
        CalendarEvent.update(event.post)
      end
    end
  end
end
