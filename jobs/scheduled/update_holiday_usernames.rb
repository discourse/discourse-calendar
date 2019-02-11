module Jobs
  class ::DiscourseCalendar::UpdateHolidayUsernames < Jobs::Scheduled
    every 1.hour

    PLUGIN_NAME ||= "calendar".freeze

    def execute(args)
      return unless topic_id = SiteSetting.holiday_calendar_topic_id
      return unless op = Post.find_by(topic_id: topic_id, post_number: 1)
      return unless details = op.custom_fields[::DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD]

      user_ids = []
      users_on_holiday = []

      details.values.each do |_, from, to, username|
        from_time = Time.parse(from)
        to_time   = to ? Time.parse(to) : from_time + 24.hours

        if from_time < Time.zone.now && Time.zone.now < to_time
          users_on_holiday << username

          user = User.find_by(username_lower: username)
          user.custom_fields[::DiscourseCalendar::HOLIDAY_CUSTOM_FIELD] = "t"
          user.save_custom_fields(true)
          user_ids << user.id
        end
      end

      PluginStore.set(PLUGIN_NAME, DiscourseCalendar::USERS_ON_HOLIDAY_KEY, users_on_holiday)
      UserCustomField.where(name: ::DiscourseCalendar::HOLIDAY_CUSTOM_FIELD).where.not(user_id: user_ids).destroy_all
    end
  end
end
