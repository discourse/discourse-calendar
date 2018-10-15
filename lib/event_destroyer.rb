module DiscourseCalendar
  class EventDestroyer
    def self.destroy(op, post_number)
      details = op.calendar_details
      details.delete(post_number)
      op.calendar_details = details
      op.save_custom_fields(true)
    end
  end
end
