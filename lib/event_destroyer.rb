module DiscourseCalendar
  class EventDestroyer
    def self.destroy(post)
      op = post.topic&.first_post
      if op&.calendar_details.present?
        details = op.calendar_details
        details.delete(post.post_number.to_s)
        op.calendar_details = details
        op.save_custom_fields(true)
        op.publish_change_to_clients!(:calendar_change)
      end
    end
  end
end
