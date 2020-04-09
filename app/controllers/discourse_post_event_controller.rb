# frozen_string_literal: true

module DiscoursePostEvent
  class DiscoursePostEventController < ::ApplicationController
    before_action :ensure_logged_in

    before_action :ensure_discourse_post_event_enabled
    def ensure_discourse_post_event_enabled
      if !SiteSetting.discourse_post_event_enabled
        raise Discourse::NotFound
      end
    end
  end
end
