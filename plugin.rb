# frozen_string_literal: true

# name: discourse-calendar
# about: Display a calendar in the first post of a topic
# version: 0.3
# author: Daniel Waterworth, Joffrey Jaffeux
# url: https://github.com/discourse/discourse-calendar
# transpile_js: true

libdir = File.join(File.dirname(__FILE__), "vendor/holidays/lib")
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

gem 'rrule', '0.4.4', require: false

load File.expand_path('../lib/calendar_settings_validator.rb', __FILE__)

enabled_site_setting :calendar_enabled

register_asset 'stylesheets/vendor/fullcalendar.min.css'
register_asset 'stylesheets/common/discourse-calendar.scss'
register_asset 'stylesheets/common/discourse-calendar-holidays.scss'
register_asset 'stylesheets/common/upcoming-events-calendar.scss'
register_asset 'stylesheets/common/discourse-post-event.scss'
register_asset 'stylesheets/common/discourse-post-event-preview.scss'
register_asset 'stylesheets/common/discourse-post-event-builder.scss'
register_asset 'stylesheets/common/discourse-post-event-invitees.scss'
register_asset 'stylesheets/common/discourse-post-event-upcoming-events.scss'
register_asset 'stylesheets/common/discourse-post-event-core-ext.scss'
register_asset 'stylesheets/mobile/discourse-post-event-core-ext.scss', :mobile
register_asset 'stylesheets/common/discourse-post-event-bulk-invite-modal.scss'
register_asset 'stylesheets/mobile/discourse-calendar.scss', :mobile
register_asset 'stylesheets/mobile/discourse-post-event.scss', :mobile
register_asset 'stylesheets/desktop/discourse-calendar.scss', :desktop
register_asset 'stylesheets/colors.scss', :color_definitions
register_asset 'stylesheets/common/user-preferences.scss'
register_svg_icon 'fas fa-calendar-day'
register_svg_icon 'fas fa-clock'
register_svg_icon 'fas fa-file-csv'
register_svg_icon 'fas fa-star'
register_svg_icon 'fas fa-file-upload'

after_initialize do
  reloadable_patch do
    Category.register_custom_field_type("sort_topics_by_event_start_date", :boolean)
    Category.register_custom_field_type("disable_topic_resorting", :boolean)
    Site.preloaded_category_custom_fields << 'sort_topics_by_event_start_date'
    Site.preloaded_category_custom_fields << 'disable_topic_resorting'
  end

  add_to_serializer :basic_category, :sort_topics_by_event_start_date do
    object.custom_fields["sort_topics_by_event_start_date"]
  end
  add_to_serializer :basic_category, :disable_topic_resorting do
    object.custom_fields["disable_topic_resorting"]
  end

  reloadable_patch do
    TopicQuery.add_custom_filter(:order_by_event_date) do |results, topic_query|
      if SiteSetting.sort_categories_by_event_start_date_enabled && topic_query.options[:category_id]
        category = Category.find_by(id: topic_query.options[:category_id])
        if category && category.custom_fields && category.custom_fields["sort_topics_by_event_start_date"]
          results = results.joins("LEFT JOIN topic_custom_fields AS custom_fields on custom_fields.topic_id = topics.id
            AND custom_fields.name = '#{DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT}'
            ").reorder("topics.pinned_at ASC, custom_fields.value ASC")
        end
      end
      results
    end
  end

  module ::DiscourseCalendar
    PLUGIN_NAME ||= 'discourse-calendar'

    # Type of calendar ('static' or 'dynamic')
    CALENDAR_CUSTOM_FIELD ||= 'calendar'

    # User custom field set when user is on holiday
    HOLIDAY_CUSTOM_FIELD ||= 'on_holiday'

    # List of all users on holiday
    USERS_ON_HOLIDAY_KEY ||= 'users_on_holiday'

    # User region used in finding holidays
    REGION_CUSTOM_FIELD ||= 'holidays-region'

    # List of groups
    GROUP_TIMEZONES_CUSTOM_FIELD ||= 'group-timezones'

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

  module ::DiscoursePostEvent
    PLUGIN_NAME ||= 'discourse-post-event'

    # Topic where op has a post event custom field
    TOPIC_POST_EVENT_STARTS_AT ||= 'TopicEventStartsAt'
    TOPIC_POST_EVENT_ENDS_AT ||= 'TopicEventEndsAt'

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePostEvent
    end
  end

  # DISCOURSE CALENDAR HOLIDAYS

  add_admin_route 'admin.calendar', 'calendar'

  %w[
    ../app/controllers/admin/admin_discourse_calendar_controller.rb
    ../app/controllers/admin/discourse_calendar/admin_holidays_controller.rb
    ../app/models/discourse_calendar/disabled_holiday.rb
    ../app/services/discourse_calendar/holiday.rb
  ].each { |path| load File.expand_path(path, __FILE__) }

  Discourse::Application.routes.append do
    mount ::DiscourseCalendar::Engine, at: '/'

    get '/admin/plugins/calendar' => 'admin/plugins#index', constraints: StaffConstraint.new
    get '/admin/discourse-calendar/holiday-regions/:region_code/holidays' => 'admin/discourse_calendar/admin_holidays#index', constraints: StaffConstraint.new
    post '/admin/discourse-calendar/holidays/disable' => 'admin/discourse_calendar/admin_holidays#disable', constraints: StaffConstraint.new
    delete '/admin/discourse-calendar/holidays/enable' => 'admin/discourse_calendar/admin_holidays#enable', constraints: StaffConstraint.new
  end

  # DISCOURSE POST EVENT

  %w[
    ../app/controllers/discourse_post_event_controller.rb
    ../app/controllers/discourse_post_event/invitees_controller.rb
    ../app/controllers/discourse_post_event/events_controller.rb
    ../app/controllers/discourse_post_event/upcoming_events_controller.rb
    ../app/models/discourse_post_event/event.rb
    ../app/models/discourse_post_event/event_date.rb
    ../app/models/discourse_post_event/invitee.rb
    ../lib/discourse_post_event/event_parser.rb
    ../lib/discourse_post_event/event_validator.rb
    ../lib/discourse_post_event/rrule_generator.rb
    ../jobs/regular/discourse_post_event/bulk_invite.rb
    ../jobs/regular/discourse_post_event/send_reminder.rb
    ../lib/discourse_post_event/event_finder.rb
    ../app/serializers/discourse_post_event/invitee_serializer.rb
    ../app/serializers/discourse_post_event/event_serializer.rb
  ].each { |path| load File.expand_path(path, __FILE__) }

  ::ActionController::Base.prepend_view_path File.expand_path(
                                               '../app/views',
                                               __FILE__
                                             )

  Discourse::Application.routes.append do
    mount ::DiscoursePostEvent::Engine, at: '/'
  end

  DiscoursePostEvent::Engine.routes.draw do
    get '/discourse-post-event/events' => 'events#index',
        format: :json
    get '/discourse-post-event/events/:id' => 'events#show'
    delete '/discourse-post-event/events/:id' => 'events#destroy'
    post '/discourse-post-event/events' => 'events#create'
    post '/discourse-post-event/events/:id/csv-bulk-invite' =>
           'events#csv_bulk_invite'
    post '/discourse-post-event/events/:id/bulk-invite' => 'events#bulk_invite',
         format: :json
    post '/discourse-post-event/events/:id/invite' => 'events#invite'
    put '/discourse-post-event/events/:post_id/invitees/:id' =>
          'invitees#update'
    post '/discourse-post-event/events/:post_id/invitees' => 'invitees#create'
    get '/discourse-post-event/events/:post_id/invitees' => 'invitees#index'
    delete '/discourse-post-event/events/:post_id/invitees/:id' =>
             'invitees#destroy'
    get '/upcoming-events' => 'upcoming_events#index'
  end

  reloadable_patch do
    Post.class_eval do
      has_one :event,
              dependent: :destroy,
              class_name: 'DiscoursePostEvent::Event',
              foreign_key: :id

      validate :valid_event
      def valid_event
        return unless self.raw_changed?
        validator = DiscoursePostEvent::EventValidator.new(self)
        validator.validate_event
      end
    end
  end

  add_to_class(:user, :can_create_discourse_post_event?) do
    if defined?(@can_create_discourse_post_event)
      return @can_create_discourse_post_event
    end
    @can_create_discourse_post_event = begin
      return true if staff?
      allowed_groups = SiteSetting.discourse_post_event_allowed_on_groups.to_s.split('|').compact
      allowed_groups.present? && groups.where(id: allowed_groups).exists?
    rescue StandardError
      false
    end
  end

  add_to_class(:guardian, :can_act_on_invitee?) do |invitee|
    user && (user.staff? || user.id == invitee.user_id)
  end

  add_to_class(:guardian, :can_create_discourse_post_event?) do
    user && user.can_create_discourse_post_event?
  end

  add_to_serializer(:current_user, :can_create_discourse_post_event) do
    object.can_create_discourse_post_event?
  end

  add_to_class(:user, :can_act_on_discourse_post_event?) do |event|
    if defined?(@can_act_on_discourse_post_event)
      return @can_act_on_discourse_post_event
    end
    @can_act_on_discourse_post_event = begin
      return true if staff?
      can_create_discourse_post_event? && Guardian.new(self).can_edit_post?(event.post)
    rescue StandardError
      false
    end
  end

  add_to_class(:guardian, :can_act_on_discourse_post_event?) do |event|
    user && user.can_act_on_discourse_post_event?(event)
  end

  add_class_method(:group, :discourse_post_event_allowed_groups) do
    where(
      id: SiteSetting.discourse_post_event_allowed_on_groups.split('|').compact
    )
  end

  TopicView.on_preload do |topic_view|
    if SiteSetting.discourse_post_event_enabled
      topic_view.instance_variable_set(:@posts, topic_view.posts.includes(:event))
    end
  end

  add_to_serializer(:post, :event) do
    DiscoursePostEvent::EventSerializer.new(
      object.event,
      scope: scope, root: false
    )
  end

  add_to_serializer(:post, :include_event?) do
    SiteSetting.discourse_post_event_enabled && !object.nil? &&
      !object.deleted_at.present?
  end

  on(:post_process_cooked) do |doc, post|
    DiscoursePostEvent::Event.update_from_raw(post)
  end

  on(:post_destroyed) do |post|
    if SiteSetting.discourse_post_event_enabled && post.event
      post.event.update!(deleted_at: Time.now)
    end
  end

  on(:post_recovered) do |post|
    if SiteSetting.discourse_post_event_enabled && post.event
      post.event.update!(deleted_at: nil)
    end
  end

  add_preloaded_topic_list_custom_field DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT

  add_to_serializer(:topic_view, :event_starts_at, false) do
    object.topic.custom_fields[DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT]
  end

  add_to_serializer(:topic_view, 'include_event_starts_at?') do
    SiteSetting.discourse_post_event_enabled &&
    SiteSetting.display_post_event_date_on_topic_title &&
    object.topic.custom_fields.keys.include?(
      DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT
    )
  end

  add_to_class(:topic, :event_starts_at) do
    @event_starts_at ||= custom_fields[DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT]
  end

  add_to_serializer(:topic_list_item, :event_starts_at, false) do
    object.event_starts_at
  end

  add_to_serializer(:topic_list_item, 'include_event_starts_at?') do
    SiteSetting.discourse_post_event_enabled &&
    SiteSetting.display_post_event_date_on_topic_title &&
    object.event_starts_at
  end

  add_preloaded_topic_list_custom_field DiscoursePostEvent::TOPIC_POST_EVENT_ENDS_AT

  add_to_serializer(:topic_view, :event_ends_at, false) do
    object.topic.custom_fields[DiscoursePostEvent::TOPIC_POST_EVENT_ENDS_AT]
  end

  add_to_serializer(:topic_view, 'include_event_ends_at?') do
    SiteSetting.discourse_post_event_enabled &&
    SiteSetting.display_post_event_date_on_topic_title &&
    object.topic.custom_fields.keys.include?(
      DiscoursePostEvent::TOPIC_POST_EVENT_ENDS_AT
    )
  end

  add_to_class(:topic, :event_ends_at) do
    @event_ends_at ||= custom_fields[DiscoursePostEvent::TOPIC_POST_EVENT_ENDS_AT]
  end

  add_to_serializer(:topic_list_item, :event_ends_at, false) do
    object.event_ends_at
  end

  add_to_serializer(:topic_list_item, 'include_event_ends_at?') do
    SiteSetting.discourse_post_event_enabled &&
    SiteSetting.display_post_event_date_on_topic_title &&
    object.event_ends_at
  end

  # DISCOURSE CALENDAR

  %w[
    ../app/models/calendar_event.rb
    ../app/serializers/user_timezone_serializer.rb
    ../jobs/scheduled/create_holiday_events.rb
    ../jobs/scheduled/delete_expired_event_posts.rb
    ../jobs/scheduled/update_holiday_usernames.rb
    ../jobs/scheduled/monitor_event_dates.rb
    ../lib/calendar_validator.rb
    ../lib/calendar.rb
    ../lib/event_validator.rb
    ../lib/group_timezones.rb
    ../lib/time_sniffer.rb
    ../lib/users_on_holiday.rb
    ../lib/holiday_status.rb
  ].each { |path| load File.expand_path(path, __FILE__) }

  register_post_custom_field_type(
    DiscourseCalendar::CALENDAR_CUSTOM_FIELD,
    :string
  )
  register_post_custom_field_type(
    DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD,
    :json
  )
  TopicView.default_post_custom_fields <<
    DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD

  register_user_custom_field_type(
    DiscourseCalendar::HOLIDAY_CUSTOM_FIELD,
    :boolean
  )

  allow_staff_user_custom_field(DiscourseCalendar::HOLIDAY_CUSTOM_FIELD)
  DiscoursePluginRegistry.serialized_current_user_fields << DiscourseCalendar::REGION_CUSTOM_FIELD
  register_editable_user_custom_field(DiscourseCalendar::REGION_CUSTOM_FIELD)

  on(:site_setting_changed) do |name, old_value, new_value|
    unless %i[all_day_event_start_time all_day_event_end_time].include? name
      next
    end

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
    if !self&.topic&.first_post&.custom_fields&.[](
         DiscourseCalendar::CALENDAR_CUSTOM_FIELD
       )
      return
    end

    validator = DiscourseCalendar::EventValidator.new(self)
    validator.validate_event
  end

  add_to_class(:post, :has_group_timezones?) do
    custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD].present?
  end

  add_to_class(:post, :group_timezones) do
    custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD] || {}
  end

  add_to_class(:post, :group_timezones=) do |val|
    if val.present?
      custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD] = val
    else
      custom_fields.delete(DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD)
    end
  end

  add_to_serializer(:post, :calendar_details) do
    grouped = {}
    standalones = []

    CalendarEvent.where(topic_id: object.topic_id).order(:start_date, :end_date).each do |event|
      if event.post_id
        standalones << {
          type: :standalone,
          post_number: event.post_number,
          message: event.description,
          from: event.start_date,
          to: event.end_date,
          username: event.username,
          recurring: event.recurrence,
          post_url: Post.url("-", event.topic_id, event.post_number),
          timezone: event.timezone
        }
      else
        identifier = "#{event.region.split("_").first}-#{event.start_date.strftime("%j")}"

        grouped[identifier] ||= {
          type: :grouped,
          from: event.start_date,
          name: [],
          usernames: []
        }

        grouped[identifier][:name] << event.description
        grouped[identifier][:usernames] << event.username
      end
    end

    grouped.each do |_, v|
      v[:name].sort!.uniq!
      v[:name] = v[:name].join(", ")
      v[:usernames].sort!.uniq!
    end

    standalones + grouped.values
  end

  add_to_serializer(:post, :include_calendar_details?) { object.is_first_post? }

  add_to_serializer(:post, :group_timezones) do
    result = {}
    group_timezones = post_custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD] || {}
    group_names = group_timezones['groups'] || []

    if group_names.present?
      users =
        User.joins(:groups, :user_option).where("groups.name": group_names)
          .select(
          'users.*',
          'groups.name AS group_name',
          'user_options.timezone'
        )

      users.each do |u|
        result[u.group_name] ||= []
        result[u.group_name] << UserTimezoneSerializer.new(u, root: false).as_json
      end
    end

    result
  end

  add_to_serializer(:post, :include_group_timezones?) do
    post_custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD].present?
  end

  add_to_serializer(:site, :users_on_holiday) do
    DiscourseCalendar.users_on_holiday
  end

  add_to_serializer(:site, :include_users_on_holiday?) { scope.is_staff? }

  reloadable_patch do
    module DiscoursePostEvent::ExportCsvControllerExtension
      def export_entity
        if post_event_export? && ensure_can_export_post_event
          Jobs.enqueue(
            :export_csv_file,
            entity: export_params[:entity],
            user_id: current_user.id,
            args: export_params[:args]
          )
          StaffActionLogger.new(current_user).log_entity_export(
            export_params[:entity]
          )
          render json: success_json
        else
          super
        end
      end

      private

      def export_params
        if post_event_export?
          @_export_params ||=
            begin
              params.require(:entity)
              params.permit(:entity, args: %i[id]).to_h
            end
        else
          super
        end
      end

      def post_event_export?
        params[:entity] === 'post_event'
      end

      def ensure_can_export_post_event
        return if !SiteSetting.discourse_post_event_enabled

        post_event = DiscoursePostEvent::Event.find(export_params[:args][:id])
        post_event && guardian.can_act_on_discourse_post_event?(post_event)
      end
    end

    require_dependency 'export_csv_controller'
    class ::ExportCsvController
      prepend DiscoursePostEvent::ExportCsvControllerExtension
    end

    module ExportPostEventCsvReportExtension
      def post_event_export(&block)
        return enum_for(:post_event_export) unless block_given?

        guardian = Guardian.new(current_user)

        event = DiscoursePostEvent::Event.includes(invitees: :user).find(@extra[:id])

        guardian.ensure_can_act_on_discourse_post_event!(event)

        event.invitees.order(:id).each do |invitee|
          yield [
            invitee.user.username,
            DiscoursePostEvent::Invitee.statuses[invitee.status],
            invitee.created_at,
            invitee.updated_at
          ]
        end
      end

      def get_header(entity)
        if SiteSetting.discourse_post_event_enabled && entity === 'post_event'
          %w[username status first_answered_at last_updated_at]
        else
          super
        end
      end
    end

    class Jobs::ExportCsvFile
      prepend ExportPostEventCsvReportExtension
    end

    on(:reduce_cooked) do |fragment, post|
      if SiteSetting.discourse_post_event_enabled
        fragment.css('.discourse-post-event').each do |event_node|
          starts_at = event_node['data-start']
          ends_at = event_node['data-end']
          dates = "#{starts_at} (#{event_node['data-timezone'] || 'UTC'})"
          dates = "#{dates} → #{ends_at} (#{event_node['data-timezone'] || 'UTC'})" if ends_at

          event_name = event_node['data-name'] || post.topic.title
          event_node.replace <<~TXT
            <div style='border:1px solid #dedede'>
              <p><a href="#{
            Discourse.base_url
          }#{post.url}">#{event_name}</a></p>
              <p>#{
            dates
          }</p>
            </div>
          TXT
        end
      end
    end

    on(:user_destroyed) do |user|
      DiscoursePostEvent::Invitee.where(user_id: user.id).destroy_all
    end

    if respond_to?(:add_post_revision_notifier_recipients)
      add_post_revision_notifier_recipients do |post_revision|
        # next if no modifications
        next if !post_revision.modifications.present?

        # do no notify recipients when only updating tags
        next if post_revision.modifications.keys == ['tags']

        ids = []
        post = post_revision.post

        if post && post.is_first_post? && post.event
          ids.concat(post.event.on_going_event_invitees.pluck(:user_id))
        end

        ids
      end
    end

    on(:site_setting_changed) do |name, old_val, new_val|
      next if name != :discourse_post_event_allowed_custom_fields

      previous_fields = old_val.split('|')
      new_fields = new_val.split('|')
      removed_fields = previous_fields - new_fields

      next if removed_fields.empty?

      DiscoursePostEvent::Event.all.find_each do |event|
        removed_fields.each { |field| event.custom_fields.delete(field) }
        event.save
      end
    end

    if defined?(DiscourseAutomation)
      on(:discourse_post_event_event_started) do |event|
        DiscourseAutomation::Automation
          .where(enabled: true, trigger: 'event_started')
          .each do |automation|
          fields = automation.serialized_fields
          topic_id = fields.dig('topic_id', 'value')

          unless event.post.topic.id.to_s == topic_id
            next
          end

          automation.trigger!(
            'kind' => 'event_started',
            'event' => event,
            'placeholders' => {
              'event_url' => event.url
            }
          )
        end
      end

      add_triggerable_to_scriptable('event_started', 'send_chat_message')

      add_automation_triggerable('event_started') do
        placeholder :event_url

        field :topic_id, component: :text
      end
    end
  end

  query = Proc.new do |notifications, data|
    notifications
      .where("data::json ->> 'topic_title' = ?", data[:topic_title].to_s)
      .where("data::json ->> 'message' = ?", data[:message].to_s)
  end

  reminders_consolidation_plan = Notifications::DeletePreviousNotifications.new(
    type: Notification.types[:event_reminder],
    previous_query_blk: query
  )

  invitation_consolidation_plan = Notifications::DeletePreviousNotifications.new(
    type: Notification.types[:event_invitation],
    previous_query_blk: query
  )

  register_notification_consolidation_plan(reminders_consolidation_plan)
  register_notification_consolidation_plan(invitation_consolidation_plan)

  Report.add_report('currently_away') do |report|
    group_filter = report.filters.dig(:group) || Group::AUTO_GROUPS[:staff]
    report.add_filter('group', type: 'group', default: group_filter)

    return unless group = Group.find_by(id: group_filter)

    report.labels = [
      {
        property: :username,
        title: I18n.t('reports.currently_away.labels.username')
      },
    ]

    group_usernames = group.users.pluck(:username)
    on_holiday_usernames = DiscourseCalendar.users_on_holiday
    report.data = (group_usernames & on_holiday_usernames).map { |username| { username: username } }
    report.total = report.data.count
  end
end
