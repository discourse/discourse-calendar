module DiscourseCalendar
  class CalendarValidator
    def initialize(post)
      @post = post
    end

    def validate_calendar
      # only OP can contain a calendar
      return false unless @post.is_first_post?

      extracted_calendars = DiscourseCalendar::Calendar::extract(@post.raw, @post.topic_id, @post.user_id)
      return false if extracted_calendars.empty?
      return false if extracted_calendars.count > 1

      calendar = extracted_calendars.first

      calendar
    end
  end
end
