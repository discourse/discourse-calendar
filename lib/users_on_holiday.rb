# frozen_string_literal: true

module DiscourseCalendar
  class UsersOnHoliday
    def self.from(calendar_events)
      calendar_events
        .filter { |e| e.user_id.present? && e.username.present? }
        .filter { |e| e.start_date < Time.zone.now && Time.zone.now < e.ends_at}
        .map { |e| {
            id: e.user_id,
            username: e.username,
            ends_at: e.ends_at
          }
        }
        .uniq { |u| u[:id] }
    end
  end
end
