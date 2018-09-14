module Jobs
  class ::DiscourseSimpleCalendar::UpdateHolidayUsernames < Jobs::Scheduled
    every 1.hour

    PLUGIN_NAME ||= "discourse_simple_calendar".freeze

    def execute(args)
      topic_id = SiteSetting.holiday_calendar_topic_id
      return if topic_id.blank?

      post_id = Post.find_by(topic_id: topic_id, post_number: 1)

      # Build a list of discourse users currently on holiday
      users_on_holiday = []
      user_ids = []

      pcf = PostCustomField.find_by(name: ::DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD, post_id: post_id)
      details = JSON.parse(pcf.value)
      details.each do |post_number, detail|
        from_time = Time.parse(detail[::DiscourseSimpleCalendar::FROM_INDEX])

        to = detail[::DiscourseSimpleCalendar::TO_INDEX] || detail[::DiscourseSimpleCalendar::FROM_INDEX]
        to_time = Time.parse(to)
        to_time += 24.hours unless detail[::DiscourseSimpleCalendar::TO_INDEX] # Add 24 hours if no explicit 'to' time

        if Time.zone.now > from_time && Time.zone.now < to_time
          username = detail[::DiscourseSimpleCalendar::USERNAME_INDEX]
          users_on_holiday << username

          user = User.find_by(username_lower: username)
          user.custom_fields[::DiscourseSimpleCalendar::HOLIDAY_CUSTOM_FIELD] = "t"
          user.save_custom_fields(true)
          user_ids << user.id
        end
      end

      PluginStore.set(PLUGIN_NAME, DiscourseSimpleCalendar::USERS_ON_HOLIDAY_KEY, users_on_holiday)
      UserCustomField.where(name: ::DiscourseSimpleCalendar::HOLIDAY_CUSTOM_FIELD).where.not(user_id: user_ids).destroy_all

      # puts "Users on holiday are #{users_on_holiday}"
    end
  end
end
