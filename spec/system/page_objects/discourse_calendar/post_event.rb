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

        def has_location?(location)
          has_css?(".event-location", text: location)
        end

        def edit
          open_more_menu
          find(".edit-event").click
        end
      end
    end
  end
end
