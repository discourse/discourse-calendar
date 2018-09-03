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

      api_key = SiteSetting.discourse_simple_calendar_mattermost_api_key
      server = SiteSetting.discourse_simple_calendar_mattermost_server

      return if api_key.blank? || server.blank?

      # Fetch all mattermost users
      response = Excon.get("#{server}/api/v4/users", headers: {
        "Authorization": "Bearer #{api_key}"
      })
      mattermost_users = JSON.parse(response.body, symbolize_names: true)

      # Loop over mattermost users
      mattermost_users.each do |user|
        mattermost_username = user[:username]
        marked_on_holiday = !!mattermost_username.chomp!("-v")

        discourse_user = User.find_by_email(user[:email])
        next unless discourse_user
        discourse_username = discourse_user.username

        on_holiday = users_on_holiday.include?(discourse_username)

        update_username = false
        if on_holiday && !marked_on_holiday
          update_username = "#{mattermost_username}-v"
        elsif !on_holiday && marked_on_holiday
          update_username = mattermost_username
        end

        if update_username
          # puts "Update #{mattermost_username} to #{update_username}"
          Excon.put("#{server}/api/v4/users/#{user[:id]}/patch", headers: {
            "Authorization": "Bearer #{api_key}"
          }, body: {
            username: update_username
          }.to_json)
        end

      end

    end

  end
end
