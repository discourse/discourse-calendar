# frozen_string_literal: true

module DiscourseCalendar
  class UsersOnHoliday
    def self.from(calendar_events)
      users_on_holiday = []
      calendar_events.each do |event|
        next if event.user_id.blank? || event.username.blank?
        end_date = event.end_date ? event.end_date : event.start_date + 24.hours
        if event.start_date < Time.zone.now && Time.zone.now < end_date
          users_on_holiday << {
            id: event.user_id,
            username: event.username,
            ends_at: end_date
          }
        end
      end

      users_on_holiday.uniq! { |u| u[:id] }
      users_on_holiday
    end
  end
end
