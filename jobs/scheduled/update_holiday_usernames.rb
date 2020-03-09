# frozen_string_literal: true

module Jobs
  class ::DiscourseCalendar::UpdateHolidayUsernames < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      return unless SiteSetting.calendar_enabled
      return unless topic_id = SiteSetting.holiday_calendar_topic_id.presence

      user_ids = []
      usernames = []

      CalendarEvent.where(topic_id: topic_id).each do |event|
        next if event.user_id.blank? || event.username.blank?
        end_date = event.end_date ? event.end_date : event.start_date + 24.hours
        if event.start_date < Time.zone.now && Time.zone.now < end_date
          user_ids << event.user_id
          usernames << event.username
        end
      end

      user_ids.uniq!
      usernames.uniq!

      PluginStore.set(DiscourseCalendar::PLUGIN_NAME, DiscourseCalendar::USERS_ON_HOLIDAY_KEY, usernames)

      custom_field_name = DiscourseCalendar::HOLIDAY_CUSTOM_FIELD

      if user_ids.present?
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
