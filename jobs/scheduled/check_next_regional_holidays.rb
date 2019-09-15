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

      UserCustomField.where(name: ::DiscourseCalendar::TIMEZONE_CUSTOM_FIELD).pluck(:user_id, :value).each do |user_id, timezone|
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
      one_month_from_now = 1.month.from_now

      users_in_region.keys.sort.each do |region|
        next unless next_holiday = Holidays.year_holidays([region]).find do |h|
          business_days === h[:date].wday && h[:date] < one_month_from_now
        end

        users_in_region[region].each do |user_id|
          next unless usernames[user_id]

          date = if tz = user_timezones[user_id]
            next_holiday[:date].in_time_zone(tz).iso8601
          else
            next_holiday[:date].to_s
          end

          new_regional_holidays << [region, next_holiday[:name], date, usernames[user_id]]
        end
      end

      if old_regional_holidays != new_regional_holidays
        op.custom_fields[::DiscourseCalendar::CALENDAR_HOLIDAYS_CUSTOM_FIELD] = new_regional_holidays
        op.save_custom_fields(true)
      end
    end
  end
end
