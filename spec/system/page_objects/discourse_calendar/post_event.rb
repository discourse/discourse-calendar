# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseCalendar
      class PostEvent < PageObjects::Pages::Base
        def open_more_menu
          find(".discourse-post-event-more-menu-trigger").click
          self
        end

        def open_bulk_invite_modal
          open_more_menu
          find(".dropdown-menu__item.bulk-invite").click
          self
        end
      end
    end
  end
end
