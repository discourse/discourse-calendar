# frozen_string_literal: true

# name: discourse-calendar
# about: Display a calendar in the first post of a topic
# version: 0.2
# author: Daniel Waterworth, Joffrey Jaffeux
# url: https://github.com/discourse/discourse-calendar

gem "holidays", "8.0.0", require: false

load File.expand_path("../lib/calendar_settings_validator.rb", __FILE__)

enabled_site_setting :calendar_enabled

register_asset "stylesheets/vendor/fullcalendar.min.css"
register_asset "stylesheets/common/discourse-calendar.scss"
register_asset "stylesheets/common/post-event.scss"
register_asset "stylesheets/mobile/discourse-calendar.scss", :mobile
register_asset "stylesheets/desktop/discourse-calendar.scss", :desktop
register_svg_icon "fas fa-calendar-day"
register_svg_icon "fas fa-question"
register_svg_icon "fas fa-clock"

after_initialize do

  module ::DiscourseCalendar
    PLUGIN_NAME ||= "discourse-calendar"

    # Type of calendar ('static' or 'dynamic')
    CALENDAR_CUSTOM_FIELD ||= "calendar"

    # User custom field set when user is on holiday
    HOLIDAY_CUSTOM_FIELD ||= "on_holiday"

    # List of all users on holiday
    USERS_ON_HOLIDAY_KEY ||= "users_on_holiday"

    # User region used in finding holidays
    REGION_CUSTOM_FIELD ||= "holidays-region"

    # List of groups
    GROUP_TIMEZONES_CUSTOM_FIELD ||= "group-timezones"

    def self.users_on_holiday
      PluginStore.get(PLUGIN_NAME, USERS_ON_HOLIDAY_KEY)
    end

    def self.users_on_holiday=(usernames)
      PluginStore.set(PLUGIN_NAME, USERS_ON_HOLIDAY_KEY, usernames)
    end

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseCalendar
    end
  end

  [
    "../app/models/calendar_event.rb",
    "../app/models/guardian.rb",
    "../app/serializers/user_timezone_serializer.rb",
    "../app/controllers/discourse_calendar_controller.rb",
    "../app/controllers/discourse_calendar/invitees_controller.rb",
    "../app/controllers/discourse_calendar/post_events_controller.rb",
    "../app/controllers/discourse_calendar/upcoming_events_controller.rb",
    "../app/models/discourse_calendar/post_event.rb",
    "../app/models/discourse_calendar/invitee.rb",
    "../app/serializers/discourse_calendar/invitee_serializer.rb",
    "../app/serializers/discourse_calendar/post_event_serializer.rb",
    "../jobs/scheduled/create_holiday_events.rb",
    "../jobs/scheduled/destroy_past_events.rb",
    "../jobs/scheduled/update_holiday_usernames.rb",
    "../lib/calendar_validator.rb",
    "../lib/calendar.rb",
    "../lib/event_validator.rb",
    "../lib/group_timezones.rb",
    "../lib/time_sniffer.rb",
  ].each { |path| load File.expand_path(path, __FILE__) }

  register_post_custom_field_type(DiscourseCalendar::CALENDAR_CUSTOM_FIELD, :string)
  register_post_custom_field_type(DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD, :json)
  TopicView.default_post_custom_fields << DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD

  register_user_custom_field_type(DiscourseCalendar::HOLIDAY_CUSTOM_FIELD, :boolean)
  whitelist_staff_user_custom_field(DiscourseCalendar::HOLIDAY_CUSTOM_FIELD)

  on(:site_setting_changed) do |name, old_value, new_value|
    next unless [:all_day_event_start_time, :all_day_event_end_time].include? name

    Post.where(id: CalendarEvent.select(:post_id).distinct).each do |post|
      CalendarEvent.update(post)
    end
  end

  on(:post_process_cooked) do |doc, post|
    DiscourseCalendar::Calendar.update(post)
    DiscourseCalendar::GroupTimezones.update(post)
    CalendarEvent.update(post)
  end

  on(:post_recovered) do |post, _, _|
    DiscourseCalendar::Calendar.update(post)
    DiscourseCalendar::GroupTimezones.update(post)
    CalendarEvent.update(post)
  end

  on(:post_destroyed) do |post, _, _|
    DiscourseCalendar::Calendar.destroy(post)
    CalendarEvent.where(post_id: post.id).destroy_all
  end

  validate(:post, :validate_calendar) do |force = nil|
    return unless self.raw_changed? || force

    validator = DiscourseCalendar::CalendarValidator.new(self)
    validator.validate_calendar
  end

  validate(:post, :validate_event) do |force = nil|
    return unless self.raw_changed? || force
    return if self.is_first_post?

    # Skip if not a calendar topic
    return if !self&.topic&.first_post&.custom_fields&.[](DiscourseCalendar::CALENDAR_CUSTOM_FIELD)

    validator = DiscourseCalendar::EventValidator.new(self)
    validator.validate_event
  end

  Post.class_eval do
    def has_group_timezones?
      custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD].present?
    end

    def group_timezones
      custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD] || {}
    end

    def group_timezones=(val)
      if val.present?
        custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD] = val
      else
        custom_fields.delete(DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD)
      end
    end
  end

  add_to_serializer(:post, :calendar_details) do
    result = []
    grouped_events = {}

    CalendarEvent.where(topic_id: object.topic_id).each do |event|
      # Events with no `post_id` are holidays
      if event.post_id
        result << {
          type: :standalone,
          post_number: event.post_number,
          message: event.description,
          from: event.start_date,
          to: event.end_date,
          username: event.username,
          recurring: event.recurrence,
          post_url: Post.url('-', event.topic_id, event.post_number)
        }
      else
        identifier = "#{event.region.split("_").first}-#{event.description}-#{event.start_date.strftime("%W")}"

        if grouped_events[identifier]
          grouped_events[identifier][:to] = event.start_date
        else
          grouped_events[identifier] = {
            type: :grouped,
            name: event.description,
            from: event.start_date,
            usernames: []
          }
        end

        grouped_events[identifier][:usernames] << event.username
        grouped_events[identifier][:usernames].uniq!
      end
    end

    result.concat(grouped_events.values)
  end

  add_to_serializer(:post, :include_calendar_details?) do
    object.is_first_post?
  end

  add_to_serializer(:post, :group_timezones) do
    result = {}
    group_names = object.group_timezones["groups"] || []

    if group_names.present?
      users = User
        .joins(:groups, :user_option)
        .where("groups.name": group_names)
        .select("users.*", "groups.name AS group_name", "user_options.timezone")

      users.each do |u|
        result[u.group_name] ||= []
        result[u.group_name] << UserTimezoneSerializer.new(u, root: false).as_json
      end
    end

    result
  end

  add_to_serializer(:post, :include_group_timezones?) do
    object.group_timezones.present?
  end

  add_to_serializer(:site, :users_on_holiday) do
    DiscourseCalendar.users_on_holiday
  end

  add_to_serializer(:site, :include_users_on_holiday?) do
    scope.is_staff?
  end

  require 'post'
  class ::Post
    has_one :post_event,
      dependent: :destroy,
      class_name: 'DiscourseCalendar::PostEvent',
      foreign_key: :id
  end

  add_to_serializer(:post, :post_event) do
    DiscourseCalendar::PostEventSerializer.new(object.post_event, scope: scope, root: false)
  end

  add_to_serializer(:post, :include_post_event?) do
    SiteSetting.post_event_enabled
  end

  Discourse::Application.routes.append do
    mount ::DiscourseCalendar::Engine, at: '/'
  end

  DiscourseCalendar::Engine.routes.draw do
    get '/discourse-calendar/post-events/:id' => 'post_events#show'
    delete '/discourse-calendar/post-events/:id' => 'post_events#destroy'
    get '/discourse-calendar/post-events' => 'post_events#index'
    post '/discourse-calendar/post-events' => 'post_events#create'
    put '/discourse-calendar/post-events/:id' => 'post_events#update'
    post '/discourse-calendar/post-events/:id/invite' => 'post_events#invite'
    put '/discourse-calendar/invitees/:id' => 'invitees#update'
    post '/discourse-calendar/invitees' => 'invitees#create'
    get '/discourse-calendar/invitees' => 'invitees#index'
    get '/upcoming-events' => 'upcoming_events#index'
  end

  DiscourseEvent.on(:post_destroyed) do |post|
    if SiteSetting.post_event_enabled && post.post_event
      post.post_event.update!(deleted_at: Time.now)
    end
  end

  DiscourseEvent.on(:post_recovered) do |post|
    if SiteSetting.post_event_enabled && post.post_event
      post.post_event.update!(deleted_at: nil)
    end
  end

  DiscourseEvent.on(:post_edited) do |post, topic_changed|
    if SiteSetting.post_event_enabled && post.post_event && post.is_first_post? && post.topic && topic_changed && post.topic != Archetype.private_message
      time_range = extract_time_range(post.topic, post.user)

      case time_range
      when TimeSniffer::Interval
        post.post_event.update!(
          starts_at: time_range.from.to_time.utc,
          ends_at: time_range.to.to_time.utc,
        )
      when TimeSniffer::Event
        post.post_event.update!(
          starts_at: time_range.at.to_time.utc
        )
      end

      post.post_event.publish_update!
    end
  end

  def extract_time_range(topic, user)
    TimeSniffer.new(
      topic.title,
      at: topic.created_at,
      timezone: user.user_option.timezone || 'UTC',
      date_order: :sane,
      matchers: [:tomorrow, :date, :time],
    ).sniff
  end

  DiscourseEvent.on(:topic_created) do |topic, args, user|
    if SiteSetting.post_event_enabled && topic.archetype != Archetype.private_message
      time_range = extract_time_range(topic, user)

      case time_range
      when TimeSniffer::Interval
        DiscourseCalendar::PostEvent.create!(
          id: topic.first_post.id,
          starts_at: time_range.from.to_time.utc,
          ends_at: time_range.to.to_time.utc,
          status: DiscourseCalendar::PostEvent.statuses[:standalone]
        )
      when TimeSniffer::Event
        DiscourseCalendar::PostEvent.create!(
          id: topic.first_post.id,
          starts_at: time_range.at.to_time.utc,
          status: DiscourseCalendar::PostEvent.statuses[:standalone]
        )
      end
    end
  end
end
