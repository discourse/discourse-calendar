# frozen_string_literal: true

module Admin::DiscourseCalendar
  class AdminDiscourseCalendarController < Admin::AdminController
    before_action :ensure_calendar_enabled

    def ensure_calendar_enabled
      raise Discourse::NotFound if !SiteSetting.calendar_enabled
    end
  end
end
