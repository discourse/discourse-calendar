# frozen_string_literal: true

module Jobs
  class ::DiscourseCalendar::CheckNextRegionalHolidays < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      return unless SiteSetting.calendar_enabled
      return unless topic_id = SiteSetting.holiday_calendar_topic_id
      return unless op = Post.find_by(topic_id: topic_id, post_number: 1)

      require "holidays" unless defined?(Holidays)

      user_ids = []
      users_in_region = Hash.new { |h, k| h[k] = [] }

      UserCustomField.where(name: ::DiscourseCalendar::REGION_CUSTOM_FIELD).pluck(:user_id, :value).each do |user_id, region|
        user_ids << user_id
        users_in_region[region] << user_id
      end

      user_timezones = {}

      user_ids_and_timezones = if DiscourseCalendar::USER_OPTIONS_TIMEZONE_ENABLED
        UserOption.pluck(:user_id, :timezone)
      else
        UserCustomField.where(name: ::DiscourseCalendar::TIMEZONE_CUSTOM_FIELD).pluck(:user_id, :value)
      end

      user_ids_and_timezones.each do |user_id, timezone|
        user_timezones[user_id] = (TZInfo::Timezone.get(timezone) rescue nil)
      end

      usernames = User
        .real
        .activated
        .not_suspended
        .not_silenced
        .where(id: user_ids)
        .pluck(:id, :username_lower)
        .to_h

      old_regional_holidays = op.custom_fields[::DiscourseCalendar::CALENDAR_HOLIDAYS_CUSTOM_FIELD] || []
      new_regional_holidays = []

      business_days = 1..5
      load_until = 6.months.from_now
      today = Date.today

      users_in_region.keys.sort.each do |region|
        holidays = Holidays.between(today, load_until, [region]).filter do |h|
          business_days === h[:date].wday
        end

        holidays.each do |next_holiday|
          users_in_region[region].each do |user_id|
            date = if tz = user_timezones[user_id]
              next_holiday[:date].in_time_zone(tz).iso8601
            else
              next_holiday[:date].to_s
            end

            next unless usernames[user_id]
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
