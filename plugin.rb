# name: discourse-calendar
# about: Display a calendar in the first post of a topic
# version: 0.1
# author: Joffrey Jaffeux
# url: https://github.com/discourse/discourse-calendar

enabled_site_setting :calendar_enabled

register_asset "stylesheets/vendor/fullcalendar.min.css"
register_asset "stylesheets/common/discourse-calendar.scss"

PLUGIN_NAME ||= "calendar".freeze
DATA_PREFIX ||= "data-calendar-".freeze

after_initialize do
  module ::DiscourseCalendar
    CALENDAR_CUSTOM_FIELD ||= "calendar"
    CALENDAR_DETAILS_CUSTOM_FIELD ||= "calendar-details"

    HOLIDAY_CUSTOM_FIELD ||= "on_holiday"
    USERS_ON_HOLIDAY_KEY ||= "users_on_holiday"

    MESSAGE_INDEX = 0
    FROM_INDEX = 1
    TO_INDEX = 2
    USERNAME_INDEX = 3
    RECURRING_INDEX = 4

    def self.users_on_holiday
      PluginStore.get(PLUGIN_NAME, USERS_ON_HOLIDAY_KEY)
    end
  end

  [
    "../lib/calendar_validator.rb",
    "../lib/calendar_updater.rb",
    "../lib/calendar_destroyer.rb",
    "../lib/event_validator.rb",
    "../lib/event_updater.rb",
    "../lib/event_destroyer.rb",
    "../jobs/scheduled/ensure_expired_event_destruction.rb",
    "../jobs/scheduled/update_holiday_usernames.rb",
  ].each { |path| load File.expand_path(path, __FILE__) }

  register_post_custom_field_type(DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD, :json)
  register_post_custom_field_type(DiscourseCalendar::CALENDAR_CUSTOM_FIELD, :string)

  whitelist_staff_user_custom_field(::DiscourseCalendar::HOLIDAY_CUSTOM_FIELD)

  class DiscourseCalendar::Calendar
    class << self
      def extract(post)
        cooked = PrettyText.cook(post.raw, topic_id: post.topic_id, user_id: post.user_id)

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

  class DiscourseCalendar::Event
    class << self
      def count(post)
        cooked = PrettyText.cook(post.raw, topic_id: post.topic_id, user_id: post.user_id)
        Nokogiri::HTML(cooked).css('span.discourse-local-date').count
      end
    end
  end

  on(:post_process_cooked) do |doc, post|
    DistributedMutex.synchronize("#{PLUGIN_NAME}-#{post.id}") do
      DiscourseCalendar::EventUpdater.update(post)
    end
  end

  on(:post_recovered) do |post, _, _|
    DistributedMutex.synchronize("#{PLUGIN_NAME}-#{post.id}") do
      DiscourseCalendar::EventUpdater.update(post)
    end
  end

  on(:post_destroyed) do |post, _, _|
    DistributedMutex.synchronize("#{PLUGIN_NAME}-#{post.id}") do
      DiscourseCalendar::EventDestroyer.destroy(post)
    end
  end

  validate(:post, :validate_post) do |force = nil|
    return unless self.raw_changed? || force
    return if self.is_first_post?

    validator = DiscourseCalendar::EventValidator.new(self)
    validator.validate_event
  end

  validate(:post, :validate_calendar) do |force = nil|
    return unless self.raw_changed? || force

    validator = DiscourseCalendar::CalendarValidator.new(self)
    self.calendar = validator.validate_calendar
  end

  Post.class_eval do
    attr_accessor :calendar

    def calendar_details
      details = custom_fields[DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD] || {}
      details = details[0] if details.kind_of?(Array) # investigate why sometimes it has been saved as an array
      details
    end

    def calendar_details=(val)
      custom_fields[DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD] = val
    end

    def set_calendar_event(post_number, detail)
      details = self.calendar_details
      details[post_number.to_s] = detail
      self.calendar_details = details
    end

    after_save do
      if self.calendar
        DistributedMutex.synchronize("#{PLUGIN_NAME}-#{self.id}") do
          DiscourseCalendar::CalendarUpdater.update(self)
          self.publish_change_to_clients!(:calendar_change)
        end
      end
    end
  end

  TopicView.default_post_custom_fields << DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD

  require_dependency "post_serializer"
  class ::PostSerializer
    attributes :calendar_details

    def calendar_details
      return nil unless object.is_first_post?
      details = post_custom_fields[DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD]

      Array(details).map do |post_number, detail|
        detail = Array(detail)

        event = {
          post_number: post_number,
          message: detail[DiscourseCalendar::MESSAGE_INDEX],
          username: detail[DiscourseCalendar::USERNAME_INDEX],
          from: detail[DiscourseCalendar::FROM_INDEX],
          recurring: detail[DiscourseCalendar::RECURRING_INDEX]
        }

        if to = detail[DiscourseCalendar::TO_INDEX]
          event[:to] = to
        end

        event
      end
    end
  end

  add_to_serializer(:site, :users_on_holiday) do
    DiscourseCalendar.users_on_holiday
  end

  add_to_serializer(:site, 'include_users_on_holiday?') do
    scope.is_staff?
  end
end
