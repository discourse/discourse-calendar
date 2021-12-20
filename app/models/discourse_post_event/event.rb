# frozen_string_literal: true

module DiscoursePostEvent
  class Event < ActiveRecord::Base
    PUBLIC_GROUP = 'trust_level_0'

    self.table_name = 'discourse_post_event_events'

    self.ignored_columns = %w(starts_at ends_at)

    has_many :event_dates, dependent: :destroy

    def self.attributes_protected_by_default
      super - %w[id]
    end

    after_commit :destroy_topic_custom_field, on: %i[destroy]
    def destroy_topic_custom_field
      if self.post && self.post.is_first_post?
        TopicCustomField.where(
          topic_id: self.post.topic_id, name: TOPIC_POST_EVENT_STARTS_AT
        ).delete_all

        TopicCustomField.where(
          topic_id: self.post.topic_id, name: TOPIC_POST_EVENT_ENDS_AT
        ).delete_all
      end
    end

    after_commit :create_or_update_event_date, on: %i(create update)
    def create_or_update_event_date
      starts_at_changed = saved_change_to_original_starts_at
      ends_at_changed = saved_change_to_original_ends_at

      # No one of date changed => Must keep the event
      return if !starts_at_changed && !ends_at_changed

      # One of date changed => Must delete the event_date and create new event_date on this event
      event_dates.update_all(deleted_at: Time.current)
      set_next_date
    end

    def set_next_date
      next_dates = calculate_next_date
      return if !next_dates

      event_dates.create!(
        starts_at: next_dates[:starts_at],
        ends_at: next_dates[:ends_at]
      ) do |event_date|
        if next_dates[:ends_at] && next_dates[:ends_at] < Time.current
          event_date.finished_at = next_dates[:ends_at]
        end
      end

      publish_update!
      invitees.update_all(status: nil, notified: false)
      notify_invitees!
      notify_missing_invitees!
    end

    has_many :invitees, foreign_key: :post_id, dependent: :delete_all
    belongs_to :post, foreign_key: :id

    scope :visible, -> { where(deleted_at: nil) }

    def expired?
      !!(self.ends_at && Time.now > self.ends_at)
    end

    def starts_at
      event_dates.pending.order(:starts_at).last&.starts_at ||
        event_dates.order(:updated_at, :id).last&.starts_at
    end

    def ends_at
      event_dates.pending.order(:starts_at).last&.ends_at ||
        event_dates.order(:updated_at, :id).last&.ends_at
    end

    validates :original_starts_at, presence: true

    def on_going_event_invitees
      return [] if !self.ends_at && self.starts_at < Time.now

      if self.ends_at
        extended_ends_at =
          self.ends_at +
          SiteSetting.discourse_post_event_edit_notifications_time_extension.minutes
        return [] if !(self.starts_at..extended_ends_at).cover?(Time.now)
      end

      invitees.where(status: DiscoursePostEvent::Invitee.statuses[:going])
    end

    MIN_NAME_LENGTH = 5
    MAX_NAME_LENGTH = 30
    validates :name,
              length: { in: MIN_NAME_LENGTH..MAX_NAME_LENGTH },
              unless: ->(event) { event.name.blank? }

    validate :raw_invitees_length
    def raw_invitees_length
      if self.raw_invitees && self.raw_invitees.length > 10
        errors.add(
          :base,
          I18n.t(
            'discourse_post_event.errors.models.event.raw_invitees_length
',
            count: 10
          )
        )
      end
    end

    validate :raw_invitees_are_groups
    def raw_invitees_are_groups
      if self.raw_invitees && User.select(:id).where(username: self.raw_invitees).limit(1).count > 0
        errors.add(:base, I18n.t('discourse_post_event.errors.models.event.raw_invitees.only_group'))
      end
    end

    validate :ends_before_start
    def ends_before_start
      if self.original_starts_at && self.original_ends_at && self.original_starts_at >= self.original_ends_at
        errors.add(
          :base,
          I18n.t(
            'discourse_post_event.errors.models.event.ends_at_before_starts_at'
          )
        )
      end
    end

    validate :allowed_custom_fields
    def allowed_custom_fields
      allowed_custom_fields =
        SiteSetting.discourse_post_event_allowed_custom_fields.split('|')
      self.custom_fields.each do |key, value|
        if !allowed_custom_fields.include?(key)
          errors.add(
            :base,
            I18n.t(
              'discourse_post_event.errors.models.event.custom_field_is_invalid',
              field: key
            )
          )
        end
      end
    end

    def create_invitees(attrs)
      timestamp = Time.now
      attrs.map! do |attr|
        {
          post_id: self.id, created_at: timestamp, updated_at: timestamp
        }.merge(attr)
      end

      self.invitees.insert_all!(attrs)
    end

    def notify_invitees!(predefined_attendance: false)
      self.invitees.where(notified: false).find_each do |invitee|
        create_notification!(
          invitee.user,
          self.post,
          predefined_attendance: predefined_attendance
        )
        invitee.update!(notified: true)
      end
    end

    def notify_missing_invitees!
      if self.private?
        self.missing_users.each do |user|
          create_notification!(user, self.post)
        end
      end
    end

    def create_notification!(user, post, predefined_attendance: false)
      return if post.event.starts_at < Time.current

      message =
        if predefined_attendance
          'discourse_post_event.notifications.invite_user_predefined_attendance_notification'
        else
          'discourse_post_event.notifications.invite_user_notification'
        end

      user.notifications.create!(
        notification_type: Notification.types[:event_invitation] || Notification.types[:custom],
        topic_id: post.topic_id,
        post_number: post.post_number,
        data: {
          topic_title: self.name || post.topic.title,
          display_username: post.user.username,
          message: message
        }.to_json
      )
    end

    def ongoing?
      (
        self.ends_at ?
          (self.starts_at..self.ends_at).cover?(Time.now) :
          self.starts_at >= Time.now
      ) && !self.expired?
    end

    def self.statuses
      @statuses ||= Enum.new(standalone: 0, public: 1, private: 2)
    end

    def public?
      status == Event.statuses[:public]
    end

    def standalone?
      status == Event.statuses[:standalone]
    end

    def private?
      status == Event.statuses[:private]
    end

    def most_likely_going(limit = SiteSetting.displayed_invitees_limit)
      going = self.invitees.order(%i[status user_id]).limit(limit)

      if self.private? && going.count < limit
        # invitees are only created when an attendance is set
        # so we create a dummy invitee object with only what's needed for serializer
        going =
          going +
          missing_users(going.pluck(:user_id))
            .limit(limit - going.count)
            .map { |user| Invitee.new(user: user, post_id: self.id) }
      end

      going
    end

    def publish_update!
      self.post.publish_message!(
        "/discourse-post-event/#{self.post.topic_id}",
        id: self.id
      )
    end

    def fetch_users
      @fetched_users ||= Invitee.extract_uniq_usernames(self.raw_invitees)
    end

    def enforce_private_invitees!
      self.invitees.where.not(user_id: fetch_users.select(:id)).delete_all
    end

    def can_user_update_attendance(user)
      !self.expired? &&
        (
          self.public? ||
            (
              self.private? &&
                (
                  self.invitees.exists?(user_id: user.id) ||
                    (user.groups.pluck(:name) & self.raw_invitees).any?
                )
            )
        )
    end

    def self.update_from_raw(post)
      events = DiscoursePostEvent::EventParser.extract_events(post)

      if events.present?
        event_params = events.first
        event = post.event || DiscoursePostEvent::Event.new(id: post.id)
        params = {
          name: event_params[:name],
          original_starts_at: event_params[:start],
          original_ends_at: event_params[:end],
          url: event_params[:url],
          recurrence: event_params[:recurrence],
          status: event_params[:status].present? ? Event.statuses[event_params[:status].to_sym] : event.status,
          reminders: event_params[:reminders],
          raw_invitees: event_params[:"allowed-groups"] ? event_params[:"allowed-groups"].split(',') : nil
        }

        params[:custom_fields] = {}
        SiteSetting.discourse_post_event_allowed_custom_fields.split("|").each do |setting|
          if event_params[setting.to_sym].present?
            params[:custom_fields][setting] = event_params[setting.to_sym]
          end
        end

        event.update_with_params!(params)
      elsif post.event
        post.event.destroy!
      end
    end

    def missing_users(excluded_ids = self.invitees.select(:user_id))
      User
        .joins(:groups)
        .where('groups.name' => self.raw_invitees)
        .where.not(id: excluded_ids)
        .distinct
    end

    def update_with_params!(params)
      case params[:status] ? params[:status].to_i : self.status
      when Event.statuses[:private]
        if params.key?(:raw_invitees)
          params = params.merge(raw_invitees: Array(params[:raw_invitees]) - [PUBLIC_GROUP])
        else
          params = params.merge(raw_invitees: Array(self.raw_invitees) - [PUBLIC_GROUP])
        end
        self.update!(params)
        self.enforce_private_invitees!
      when Event.statuses[:public]
        self.update!(params.merge(raw_invitees: [PUBLIC_GROUP]))
      when Event.statuses[:standalone]
        self.update!(params.merge(raw_invitees: []))
        self.invitees.destroy_all
      end

      self.publish_update!
    end

    def calculate_next_date
      return { starts_at: original_starts_at, ends_at: original_ends_at } if !original_ends_at || self.recurrence.blank? || original_starts_at > Time.current

      recurrence = nil

      case self.recurrence
      when 'every_day'
        recurrence = 'FREQ=DAILY'
      when 'every_month'
        start_date = original_starts_at.beginning_of_month.to_date
        end_date = original_starts_at.end_of_month.to_date
        weekday = original_starts_at.strftime('%A')

        count = 0
        (start_date..end_date).each do |date|
          count += 1 if date.strftime('%A') == weekday
          break if date.day == original_starts_at.day
        end

        recurrence = "FREQ=MONTHLY;BYDAY=#{count}#{weekday.upcase[0, 2]}"
      when 'every_weekday'
        recurrence = 'FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR'
      when 'every_two_weeks'
        recurrence = "FREQ=WEEKLY;INTERVAL=2;"
      else
        byday = original_starts_at.strftime('%A').upcase[0, 2]
        recurrence = "FREQ=WEEKLY;BYDAY=#{byday}"
      end

      next_starts_at = RRuleGenerator.generate(recurrence, original_starts_at)
      difference = original_ends_at - original_starts_at
      next_ends_at = next_starts_at + difference.seconds

      { starts_at: next_starts_at, ends_at: next_ends_at }
    end
  end
end
