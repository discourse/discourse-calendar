# frozen_string_literal: true

require "holidays"

module Admin::DiscourseCalendar
  class AdminHolidaysController < AdminDiscourseCalendarController
    def index
      region_code = params[:region_code]

      begin
        holidays = Holidays.year_holidays([region_code], Time.current.beginning_of_year)
      rescue Holidays::InvalidRegion
        return render_json_error(I18n.t("system_messages.discourse_calendar_holiday_region_invalid"), 422)
      end

      render json: { region_code: region_code, holidays: holidays }
    end
  end
end
