module Jobs
  class ::DiscourseSimpleCalendar::UpdateHolidayUsernames < Jobs::Scheduled
    every 1.hour

    PLUGIN_NAME ||= "discourse_simple_calendar".freeze

    def execute(args)
      post_id = SiteSetting.discourse_simple_calendar_holiday_post_id

      return if post_id.blank?

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

          user = User.find_by(username: username)
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
