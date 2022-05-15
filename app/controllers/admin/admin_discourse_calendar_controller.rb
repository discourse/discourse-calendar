# frozen_string_literal: true

module Admin::DiscourseCalendar
  class AdminDiscourseCalendarController < Admin::AdminController
    before_action :ensure_calendar_enabled

    def ensure_calendar_enabled
      if !SiteSetting.calendar_enabled
        raise Discourse::NotFound
      end
    end
  end
end
