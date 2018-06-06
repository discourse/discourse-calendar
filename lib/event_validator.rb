module DiscourseSimpleCalendar
  class EventValidator
    def initialize(post)
      @post = post
    end

    def validate_event
      return false if @post.is_first_post?

      return false unless @post.topic.first_post.custom_fields[DiscourseSimpleCalendar::CALENDAR_CUSTOM_FIELD]

      true
    end
  end
end
