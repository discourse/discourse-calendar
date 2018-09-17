module DiscourseCalendar
  class EventValidator
    def initialize(post)
      @post = post
    end

    def validate_event
      return false if @post.is_first_post?

      calendar_custom_field = @post.topic.first_post.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD]
      return false unless calendar_custom_field
      return false if calendar_custom_field == "static"

      true
    end
  end
end
