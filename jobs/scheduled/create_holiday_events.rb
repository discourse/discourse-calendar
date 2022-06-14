# frozen_string_literal: true

module Jobs
  class ::DiscourseCalendar::CreateHolidayEvents < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      return unless SiteSetting.calendar_enabled
      return unless topic_id = SiteSetting.holiday_calendar_topic_id.presence

      require 'holidays' if !defined?(Holidays)

      regions_and_user_ids = Hash.new { |h, k| h[k] = [] }

      UserCustomField
        .where(name: ::DiscourseCalendar::REGION_CUSTOM_FIELD)
        .pluck(:user_id, :value)
        .each { |user_id, region| regions_and_user_ids[region] << user_id if region.present? }

      usernames = User
        .real
        .activated
        .not_suspended
        .not_silenced
        .where(id: regions_and_user_ids.values.flatten)
        .pluck(:id, :username)
        .to_h

      timezones = UserOption
        .where(user_id: usernames.keys)
        .where.not(timezone: nil)
        .pluck(:user_id, :timezone)
        .map { |user_id, timezone| [user_id, (TZInfo::Timezone.get(timezone) rescue nil)] }
        .to_h

      # Remove holidays for deactivated/suspended/silenced users
      CalendarEvent
        .where(post_id: nil)
        .where.not(user_id: usernames.keys)
        .delete_all

      regions_and_user_ids.each do |region, user_ids|
        DiscourseCalendar::Holiday.find_holidays_for(
          region_code: region,
          start_date: Date.today,
          end_date: 6.months.from_now,
          show_holiday_observed_on_dates: true
        )
          .filter { |holiday| (1..5) === holiday[:date].wday && holiday[:disabled] === false }
          .each do |holiday|

          user_ids.each do |user_id|
            next unless usernames[user_id]

            date = if tz = timezones[user_id]
              datetime = holiday[:date].in_time_zone(tz)
              datetime = datetime.change(hour_adjustment) if hour_adjustment
              datetime
            else
              holiday[:date]
            end

            CalendarEvent.find_or_create_by(
              topic_id: topic_id,
              user_id: user_id,
              username: usernames[user_id],
              description: holiday[:name],
              start_date: date,
              region: region
            )
          end
        end
      end
    end

    def hour_adjustment
      return if SiteSetting.all_day_event_start_time.empty? || SiteSetting.all_day_event_end_time.empty?

      @holiday_hour ||= begin
        split = SiteSetting.all_day_event_start_time.split(":")
        { hour: split.first, min: split.second }
      end
    end
  end
end
