module DiscourseCalendar
  class CalendarDestroyer
    def self.destroy(post)
      fields = [
        DiscourseCalendar::CALENDAR_CUSTOM_FIELD,
        DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD
      ]

      PostCustomField.where(post_id: post.id, name: fields)
        .delete_all
    end
  end
end
