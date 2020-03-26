# frozen_string_literal: true

module DiscourseCalendar
  class UpcomingEventsController < ::ApplicationController
    before_action :ensure_logged_in

    before_action :ensure_post_event_enabled
    def ensure_post_event_enabled
      if !SiteSetting.post_event_enabled
        raise Discourse::NotFound
      end
    end

    def index; end
  end
end
