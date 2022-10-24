# frozen_string_literal: true

module DiscourseCalendar
  class UsersOnHoliday
    def self.from(calendar_events)
      calendar_events
        .filter { |e| e.user_id.present? && e.username.present? }
        .filter { |e| e.underway? }
        .group_by(&:user_id)
        .map { |_, events| events.sort_by(&:ends_at).last }
        .to_h { |e| [
          e.user_id,
          {
            username: e.username,
            ends_at: e.ends_at
          }
        ]
        }
    end
  end
end
