# frozen_string_literal: true

module Jobs
  class ::DiscourseCalendar::UpdateHolidayUsernames < Jobs::Scheduled
    every 10.minutes

    PLUGIN_NAME ||= "calendar".freeze

    def execute(args)
      return unless SiteSetting.calendar_enabled
      return unless topic_id = SiteSetting.holiday_calendar_topic_id
      return unless op = Post.find_by(topic_id: topic_id, post_number: 1)

      events = []

      if details = op.custom_fields[::DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD]
        details.values.each do |_, from, to, username|
          events << [from, to, username]
        end
      end

      if holidays = op.custom_fields[::DiscourseCalendar::CALENDAR_HOLIDAYS_CUSTOM_FIELD]
        holidays.each do |_, _, date, username|
          events << [date, nil, username]
        end
      end

      usernames = []

      events.each do |from, to, username|
        from_time = Time.parse(from)
        to_time   = to ? Time.parse(to) : from_time + 24.hours
        usernames << username if from_time < Time.zone.now && Time.zone.now < to_time
      end

      usernames.uniq!
      usernames.compact!

      PluginStore.set(PLUGIN_NAME, DiscourseCalendar::USERS_ON_HOLIDAY_KEY, usernames)

      cf_name  = ::DiscourseCalendar::HOLIDAY_CUSTOM_FIELD
      user_ids = User.where(username_lower: usernames).pluck(:id).compact

      if user_ids.present?
        values = user_ids.map { |id| "(#{id}, '#{cf_name}', 't', now(), now())" }

        DB.exec <<~SQL, cf_name
          INSERT INTO user_custom_fields (user_id, name, value, created_at, updated_at)
          VALUES #{values.join(",")}
          ON CONFLICT (user_id, name) WHERE (name = ?) DO NOTHING
        SQL

        DB.exec <<~SQL, cf_name, user_ids
          DELETE FROM user_custom_fields
           WHERE name = ?
             AND user_id NOT IN (?)
        SQL
      else
        DB.exec("DELETE FROM user_custom_fields WHERE name = ?", cf_name)
      end
    end
  end
end
