module Jobs
  class ::DiscourseCalendar::CheckNextRegionalHolidays < Jobs::Scheduled
    every 1.hour

    def execute(args)
      return unless SiteSetting.calendar_enabled
      return unless topic_id = SiteSetting.holiday_calendar_topic_id
      return unless op = Post.find_by(topic_id: topic_id, post_number: 1)

      require "holidays" unless defined?(Holidays)

      user_ids = []
      users_in_region = {}

      UserCustomField.where(name: ::DiscourseCalendar::REGION_CUSTOM_FIELD).pluck(:user_id, :value).each do |user_id, region|
        user_ids << user_id
        users_in_region[region] ||= []
        users_in_region[region] << user_id
      end

      usernames = User.where(id: user_ids).pluck(:id, :username_lower).to_h

      old_regional_holidays = op.custom_fields[::DiscourseCalendar::CALENDAR_HOLIDAYS_CUSTOM_FIELD] || []
      new_regional_holidays = []

      users_in_region.keys.sort.each do |region|
        next if !(next_holiday = Holidays.next_holidays(1, [region]).first)
        next if next_holiday[:date] > 1.month.from_now

        date = next_holiday[:date].to_s

        users_in_region[region].each do |user_id|
          if !new_regional_holidays.find { |r, _, d, u| r == region && d == date && u == usernames[user_id] }
            new_regional_holidays << [region, next_holiday[:name], date, usernames[user_id]]
          end
        end
      end

      if old_regional_holidays != new_regional_holidays
        op.custom_fields[::DiscourseCalendar::CALENDAR_HOLIDAYS_CUSTOM_FIELD] = new_regional_holidays
        op.save_custom_fields(true)
      end
    end
  end
end
