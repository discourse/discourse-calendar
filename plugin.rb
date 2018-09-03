# name: discourse-simple-calendar
# about: Display a calendar in the first post of a topic
# version: 0.1
# author: Joffrey Jaffeux
hide_plugin if respond_to?(:hide_plugin)

enabled_site_setting :discourse_simple_calendar_enabled

register_asset "stylesheets/vendor/fullcalendar.min.css"
register_asset "stylesheets/common/discourse-simple-calendar.scss"

PLUGIN_NAME ||= "discourse_simple_calendar".freeze
DATA_PREFIX ||= "data-calendar-".freeze

after_initialize do
  module ::DiscourseSimpleCalendar
    CALENDAR_CUSTOM_FIELD ||= "dsc-calendar"
    CALENDAR_DETAILS_CUSTOM_FIELD ||= "dsc-calendar-details"

    HOLIDAY_CUSTOM_FIELD ||= "on_holiday"
    USERS_ON_HOLIDAY_KEY ||= "users_on_holiday"

    MESSAGE_INDEX = 0
    FROM_INDEX = 1
    TO_INDEX = 2
    USERNAME_INDEX = 3

    autoload :CalendarValidator, "#{Rails.root}/plugins/discourse-simple-calendar/lib/calendar_validator"
    autoload :CalendarUpdater, "#{Rails.root}/plugins/discourse-simple-calendar/lib/calendar_updater"
    autoload :CalendarDestroyer, "#{Rails.root}/plugins/discourse-simple-calendar/lib/calendar_destroyer"
    autoload :EventValidator, "#{Rails.root}/plugins/discourse-simple-calendar/lib/event_validator"
    autoload :EventUpdater, "#{Rails.root}/plugins/discourse-simple-calendar/lib/event_updater"
    autoload :EventDestroyer, "#{Rails.root}/plugins/discourse-simple-calendar/lib/event_destroyer"
  end

  require File.expand_path("../jobs/scheduled/ensure_expired_event_destruction", __FILE__)
  require File.expand_path("../jobs/scheduled/update_holiday_usernames", __FILE__)

  register_post_custom_field_type(DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD, :json)
  register_post_custom_field_type(DiscourseSimpleCalendar::CALENDAR_CUSTOM_FIELD, :string)

  whitelist_staff_user_custom_field(::DiscourseSimpleCalendar::HOLIDAY_CUSTOM_FIELD)

  class DiscourseSimpleCalendar::Calendar
    class << self
      def extract(raw, topic_id, user_id = nil)
        cooked = PrettyText.cook(raw, topic_id: topic_id, user_id: user_id)

        Nokogiri::HTML(cooked).css('div.calendar').map do |cooked_calendar|
          calendar = {}

          cooked_calendar.attributes.values.each do |attribute|
            if attribute.name.start_with?(DATA_PREFIX)
              calendar[attribute.name[DATA_PREFIX.length..-1]] = CGI.escapeHTML(attribute.value || "")
            end
          end

          calendar
        end
      end
    end
  end

  # should be moved into discourse-local-dates plugin code
  class DiscourseSimpleCalendar::Dates
    class << self
      def extract(raw, topic_id, user_id = nil)
        cooked = PrettyText.cook(raw, topic_id: topic_id, user_id: user_id)

        Nokogiri::HTML(cooked).css('span.discourse-local-date').map do |cooked_date|
          date = {}
          cooked_date.attributes.values.each do |attribute|
            if attribute.name && ['data-date', 'data-time'].include?(attribute.name)
              unless attribute.value == 'undefined'
                date[attribute.name.gsub('data-', '')] = CGI.escapeHTML(attribute.value || "")
              end
            end
          end
          date
        end
      end
    end
  end

  on(:post_process_cooked) do |doc, post|
    validator = DiscourseSimpleCalendar::EventValidator.new(post)

    if validator.validate_event
      DistributedMutex.synchronize("#{PLUGIN_NAME}-#{post.id}") do
        DiscourseSimpleCalendar::EventUpdater.update(post)
      end
    end
  end

  validate(:post, :validate_calendar) do |force = nil|
    return unless self.raw_changed? || force

    validator = DiscourseSimpleCalendar::CalendarValidator.new(self)
    calendar = validator.validate_calendar

    if calendar && calendar["type"] == "static"
      return
    end

    if calendar
      self.calendar_details = calendar
    else
      DistributedMutex.synchronize("#{PLUGIN_NAME}-#{self.id}") do
        DiscourseSimpleCalendar::CalendarDestroyer.destroy(self)
        self.publish_change_to_clients!(:calendar_change)
      end
    end

    true
  end

  Post.class_eval do
    attr_accessor :calendar_details

    after_save do
      if self.calendar_details
        DistributedMutex.synchronize("#{PLUGIN_NAME}-#{self.id}") do
          DiscourseSimpleCalendar::CalendarUpdater.update(self)
          self.publish_change_to_clients!(:calendar_change)
        end
      end
    end
  end

  TopicView.default_post_custom_fields << DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD

  require_dependency "post_serializer"
  class ::PostSerializer
    attributes :calendar_details

    def calendar_details
      return nil unless object.is_first_post?
      details = post_custom_fields[DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD]

      Array(details).map do |post_number, detail|
        detail = Array(detail)

        event = {
          post_number: post_number,
          message: detail[DiscourseSimpleCalendar::MESSAGE_INDEX],
          username: detail[DiscourseSimpleCalendar::USERNAME_INDEX],
          from: detail[DiscourseSimpleCalendar::FROM_INDEX]
        }

        if to = detail[DiscourseSimpleCalendar::TO_INDEX]
          event[:to] = to
        end

        event
      end
    end
  end

  add_to_serializer(:site, :users_on_holiday) do
    PluginStore.get(PLUGIN_NAME, DiscourseSimpleCalendar::USERS_ON_HOLIDAY_KEY)
  end
end
