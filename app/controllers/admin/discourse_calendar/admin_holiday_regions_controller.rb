# frozen_string_literal: true

require "holidays"

module Admin::DiscourseCalendar
  class AdminHolidayRegionsController < AdminDiscourseCalendarController
    def index
      render json: { holiday_regions: Holidays.available_regions }
    end
  end
end
