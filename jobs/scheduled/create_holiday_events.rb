# frozen_string_literal: true

module Jobs
  class ::DiscourseCalendar::CreateHolidayEvents < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      return unless SiteSetting.calendar_enabled
      return unless topic_id = SiteSetting.holiday_calendar_topic_id.presence

      require "holidays" unless defined?(Holidays)

      regions_and_user_ids = Hash.new { |h, k| h[k] = [] }
      UserCustomField
        .where(name: ::DiscourseCalendar::REGION_CUSTOM_FIELD)
        .pluck(:user_id, :value)
        .each { |user_id, region| regions_and_user_ids[region] << user_id }

      usernames = User
        .real
        .activated
        .not_suspended
        .not_silenced
        .where(id: regions_and_user_ids.values.flatten)
        .pluck(:id, :username)
        .to_h

      user_ids_and_timezones = UserOption
        .where.not(timezone: nil)
        .pluck(:user_id, :timezone)
        .map { |user_id, timezone| [user_id, (TZInfo::Timezone.get(timezone) rescue nil)] }
        .to_h

      regions_and_user_ids.keys.each do |region|
        holidays = Holidays
          .between(Date.today, 6.months.from_now, [region], :observed)
          .filter { |holiday| (1..5) === holiday[:date].wday }
          .each do |holiday|

          regions_and_user_ids[region].each do |user_id|
            next unless usernames[user_id]

            date = if tz = user_ids_and_timezones[user_id]
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
        split = SiteSetting.all_day_event_start_time.split(':')
        { hour: split.first, min: split.second }
      end
    end
  end
end
