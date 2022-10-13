# frozen_string_literal: true

module Jobs
  class ::DiscourseCalendar::UpdateHolidayUsernames < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      return unless SiteSetting.calendar_enabled
      return unless topic_id = SiteSetting.holiday_calendar_topic_id.presence

      events = CalendarEvent.where(topic_id: topic_id)
      users_on_holiday = DiscourseCalendar::UsersOnHoliday.from(events)

      DiscourseCalendar.users_on_holiday = users_on_holiday.map { |u| u[:username] }
      synchronize_user_custom_fields(users_on_holiday)
      set_holiday_statuses(users_on_holiday)
    end

    private

    def synchronize_user_custom_fields(users_on_holiday)
      custom_field_name = DiscourseCalendar::HOLIDAY_CUSTOM_FIELD

      if users_on_holiday.present?
        user_ids = users_on_holiday.map { |u| u[:id] }
        values = user_ids.map { |id| "(#{id}, '#{custom_field_name}', 't', now(), now())" }

        DB.exec <<~SQL, custom_field_name
          INSERT INTO user_custom_fields (user_id, name, value, created_at, updated_at)
          VALUES #{values.join(",")}
          ON CONFLICT (user_id, name) WHERE (name = ?) DO NOTHING
        SQL

        DB.exec <<~SQL, custom_field_name, user_ids
          DELETE FROM user_custom_fields
          WHERE name = ?
            AND user_id NOT IN (?)
        SQL
      else
        DB.exec("DELETE FROM user_custom_fields WHERE name = ?", custom_field_name)
      end
    end

    def set_holiday_statuses(users_on_holiday)
      return if !SiteSetting.enable_user_status
      users_on_holiday.each { |u| set_holiday_status(u) }
    end

    def set_holiday_status(user_on_holiday)
      User
        .where(id: user_on_holiday[:id])
        .each { |user| user.set_status!(
          I18n.t("discourse_calendar.holiday_status.description"),
          DiscourseCalendar::HOLIDAY_STATUS_EMOJI,
          user_on_holiday[:ends_at])
        }
    end
  end
end
