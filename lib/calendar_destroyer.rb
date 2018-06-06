module DiscourseSimpleCalendar
  class CalendarDestroyer
    def self.destroy(post)
      fields = [
        DiscourseSimpleCalendar::CALENDAR_CUSTOM_FIELD,
        DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD
      ]

      PostCustomField.where(post_id: post.id, name: fields)
                     .delete_all
    end
  end
end
