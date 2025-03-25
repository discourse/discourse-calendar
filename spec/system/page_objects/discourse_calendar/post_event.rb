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

        def create_normal_event_topic(composer, topic_page)
          visit("/latest")
          topic_page.open_new_topic

          composer.fill_title("Creating a normal event topic")
          tomorrow = (Time.zone.now + 1.day).strftime("%Y-%m-%d")
          composer.fill_content <<~MD
            [event start="#{tomorrow} 13:37" status="public"]
            [/event]
          MD
          composer.create
        end
      end
    end
  end
end
