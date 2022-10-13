# frozen_string_literal: true

module Jobs
  class ::DiscourseCalendar::UpdateHolidayUsernames < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      return unless SiteSetting.calendar_enabled
      return unless topic_id = SiteSetting.holiday_calendar_topic_id.presence

      events = CalendarEvent.where(topic_id: topic_id)
      users_on_holiday = DiscourseCalendar::UsersOnHoliday.from(events)

      DiscourseCalendar.users_on_holiday = users_on_holiday.map{ |u| u[:username] }

      custom_field_name = DiscourseCalendar::HOLIDAY_CUSTOM_FIELD

      if users_on_holiday.present?
        user_ids = users_on_holiday.map{ |u| u[:id] }
        values = user_ids.map { |id| "(#{id}, '#{custom_field_name}', 't', now(), now())" }

        DB.exec <<~SQL, custom_field_name
          INSERT INTO user_custom_fields (user_id, name, value, created_at, updated_at)
          VALUES #{values.join(",")}
          ON CONFLICT (user_id, name) WHERE (name = ?) DO NOTHING
        SQL

        DB.exec <<~SQL, custom_field_name, user_ids
          DELETE FROM user_custom_fields
           WHERE name = ?
             AND user_id NOT IN (?)
        SQL
      else
        DB.exec("DELETE FROM user_custom_fields WHERE name = ?", custom_field_name)
      end
    end
  end
end
