# frozen_string_literal: true

# name: discourse-calendar
# about: Display a calendar in the first post of a topic
# version: 0.2
# author: Joffrey Jaffeux
# url: https://github.com/discourse/discourse-calendar

gem "holidays", "8.0.0", require: false

[
  "../lib/calendar_settings_validator.rb",
].each { |path| load File.expand_path(path, __FILE__) }

enabled_site_setting :calendar_enabled

register_asset "stylesheets/vendor/fullcalendar.min.css"
register_asset "stylesheets/common/discourse-calendar.scss"
register_asset "stylesheets/mobile/discourse-calendar.scss", :mobile
register_asset "stylesheets/desktop/discourse-calendar.scss", :desktop

PLUGIN_NAME ||= "calendar"
DATA_PREFIX ||= "data-calendar-"

after_initialize do
  module ::DiscourseCalendar
    CALENDAR_CUSTOM_FIELD ||= "calendar"
    CALENDAR_DETAILS_CUSTOM_FIELD ||= "calendar-details"
    CALENDAR_HOLIDAYS_CUSTOM_FIELD ||= "calendar-holidays"

    HOLIDAY_CUSTOM_FIELD ||= "on_holiday"
    USERS_ON_HOLIDAY_KEY ||= "users_on_holiday"

    REGION_CUSTOM_FIELD ||= "holidays-region"

    HAS_GROUP_TIMEZONES_CUSTOM_FIELD ||= "has-group-timezones"
    GROUP_TIMEZONES_CUSTOM_FIELD ||= "group-timezones"
    GROUP_DATA_ATTRIBUTE ||= "data-group"

    def self.users_on_holiday
      PluginStore.get(PLUGIN_NAME, USERS_ON_HOLIDAY_KEY)
    end
  end

  [
    "../app/serializers/user_timezone_serializer.rb",
    "../lib/calendar_validator.rb",
    "../lib/calendar_updater.rb",
    "../lib/calendar_destroyer.rb",
    "../lib/event_validator.rb",
    "../lib/event_updater.rb",
    "../lib/event_destroyer.rb",
    "../lib/group_timezones_updater.rb",
    "../jobs/scheduled/ensure_expired_event_destruction.rb",
    "../jobs/scheduled/update_holiday_usernames.rb",
    "../jobs/scheduled/check_next_regional_holidays.rb",
    "../jobs/scheduled/ensure_consistency.rb",
  ].each { |path| load File.expand_path(path, __FILE__) }

  register_post_custom_field_type(DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD, :json)
  register_post_custom_field_type(DiscourseCalendar::CALENDAR_HOLIDAYS_CUSTOM_FIELD, :json)
  register_post_custom_field_type(DiscourseCalendar::CALENDAR_CUSTOM_FIELD, :string)
  register_post_custom_field_type(DiscourseCalendar::HAS_GROUP_TIMEZONES_CUSTOM_FIELD, :boolean)
  register_post_custom_field_type(DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD, :json)

  register_user_custom_field_type(DiscourseCalendar::HOLIDAY_CUSTOM_FIELD, :boolean)

  whitelist_staff_user_custom_field(DiscourseCalendar::HOLIDAY_CUSTOM_FIELD)

  DiscourseEvent.on(:site_setting_changed) do |name, old_value, new_value|
    next unless [:all_day_event_start_time, :all_day_event_end_time].include? name

    post_ids = PostCustomField.where(name: DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD).pluck(:post_id)
    Post.where(id: post_ids).each do |topic_post|
      Post.where(topic_id: topic_post.topic_id).each do |post|
        DiscourseCalendar::EventUpdater.update(post)
      end
    end
  end

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
      DiscourseCalendar::GroupTimezonesUpdater.update(post)
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

    op = self&.topic&.first_post
    if op&.custom_fields
      return if !op.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD]
    end

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

    def calendar_holidays
      custom_fields[DiscourseCalendar::CALENDAR_HOLIDAYS_CUSTOM_FIELD] || []
    end

    def calendar_details
      custom_fields[DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD] || {}
    end

    def calendar_details=(val)
      custom_fields[DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD] = val
    end

    def has_group_timezones?
      custom_fields[DiscourseCalendar::HAS_GROUP_TIMEZONES_CUSTOM_FIELD] || false
    end

    def has_group_timezones=(val)
      custom_fields[DiscourseCalendar::HAS_GROUP_TIMEZONES_CUSTOM_FIELD] = val
    end

    def group_timezones
      custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD] || {}
    end

    def group_timezones=(val)
      custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD] = val
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
  TopicView.default_post_custom_fields << DiscourseCalendar::CALENDAR_HOLIDAYS_CUSTOM_FIELD
  TopicView.default_post_custom_fields << DiscourseCalendar::HAS_GROUP_TIMEZONES_CUSTOM_FIELD
  TopicView.default_post_custom_fields << DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD

  add_to_serializer(:post, :calendar_details) do
    result = []

    details = post_custom_fields[DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD]
    Array(details).each do |post_number, (message, from, to, username, recurring, post_url)|
      result << {
        type: :standalone,
        post_number: post_number.to_i,
        message: message,
        from: from,
        to: to,
        username: username,
        recurring: recurring,
        post_url: post_url
      }
    end

    grouped_events = {}
    holidays = post_custom_fields[DiscourseCalendar::CALENDAR_HOLIDAYS_CUSTOM_FIELD]
    Array(holidays).each do |region, name, date, username|
      country_code = region.split("_").first
      identifier = "#{country_code}-#{name}"

      if grouped_events[identifier]
        grouped_events[identifier][:to] = date
      else
        grouped_events[identifier] ||= {
          type: :grouped,
          name: name,
          from: date,
          usernames: []
        }
      end

      grouped_events[identifier][:usernames] << username
      grouped_events[identifier][:usernames].uniq!
    end

    result.concat(grouped_events.values)
  end

  add_to_serializer(:post, :include_calendar_details?) do
    object.is_first_post? && (
      object.custom_fields[DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD] ||
      object.custom_fields[DiscourseCalendar::CALENDAR_HOLIDAYS_CUSTOM_FIELD]
    )
  end

  add_to_serializer(:post, :group_timezones) do
    result = {}
    group_names = object.group_timezones["groups"] || []

    if group_names.present?
      users = User.joins(:groups, :user_option).where("groups.name": group_names).select("users.*", "groups.name AS group_name", "user_options.timezone")

      users.each do |u|
        result[u.group_name] ||= []
        result[u.group_name] << UserTimezoneSerializer.new(u, root: false).as_json
      end
    end

    result
  end

  add_to_serializer(:post, :include_group_timezones?) do
    post_custom_fields[DiscourseCalendar::HAS_GROUP_TIMEZONES_CUSTOM_FIELD] || false
  end

  add_to_serializer(:site, :users_on_holiday) { DiscourseCalendar.users_on_holiday }
  add_to_serializer(:site, :include_users_on_holiday?) { scope.is_staff? }
end
