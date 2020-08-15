# frozen_string_literal: true

module DiscoursePostEvent
  class Event < ActiveRecord::Base
    PUBLIC_GROUP = 'trust_level_0'

    self.table_name = 'discourse_post_event_events'

    def self.attributes_protected_by_default
      super - %w[id]
    end

    after_commit :destroy_topic_custom_field, on: %i[destroy]
    def destroy_topic_custom_field
      if self.post && self.post.is_first_post?
        TopicCustomField.where(
          topic_id: self.post.topic_id, name: TOPIC_POST_EVENT_STARTS_AT
        ).delete_all
      end
    end

    after_commit :upsert_topic_custom_field, on: %i[create update]
    def upsert_topic_custom_field
      if self.post && self.post.is_first_post?
        TopicCustomField.upsert(
          {
            topic_id: self.post.topic_id,
            name: TOPIC_POST_EVENT_STARTS_AT,
            value: self.starts_at,
            created_at: Time.now,
            updated_at: Time.now
          },
          unique_by: %i[name topic_id]
        )
      end
    end

    after_commit :setup_handlers, on: %i[create update]
    def setup_handlers
      starts_at_changes = saved_change_to_starts_at
      self.refresh_starts_at_handlers!(starts_at_changes) if starts_at_changes

      if saved_change_to_starts_at || saved_change_to_reminders
        self.refresh_reminders!
      end

      ends_at_changes = saved_change_to_ends_at
      self.refresh_ends_at_handlers!(ends_at_changes) if ends_at_changes

      if starts_at_changes
        self.invitees.update_all(status: nil, notified: false)
        self.notify_invitees!
        self.notify_missing_invitees!
      end
    end

    has_many :invitees, foreign_key: :post_id, dependent: :delete_all
    belongs_to :post, foreign_key: :id

    scope :visible, -> { where(deleted_at: nil) }

    scope :expired, -> { where('ends_at IS NOT NULL AND ends_at < ?', Time.now) }
    scope :not_expired, -> { where('ends_at IS NULL OR ends_at > ?', Time.now) }

    def expired?
      !!(self.ends_at && Time.now > self.ends_at)
    end

    validates :starts_at, presence: true

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
      if self.starts_at && self.ends_at && self.starts_at >= self.ends_at
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
        self.missing_group_users.each do |group_user|
          create_notification!(group_user.user, self.post)
        end
      end
    end

    def create_notification!(user, post, predefined_attendance: false)
      message =
        if predefined_attendance
          'discourse_post_event.notifications.invite_user_predefined_attendance_notification'
        else
          'discourse_post_event.notifications.invite_user_notification'
        end

      user.notifications.create!(
        notification_type: Notification.types[:custom],
        topic_id: post.topic_id,
        post_number: post.post_number,
        data: {
          topic_title: post.topic.title,
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
            GroupUser.includes(:group, :user).where(
              'groups.name' => self.raw_invitees
            ).where.not('users.id' => going.pluck(:user_id)).limit(
              limit - going.count
            ).map { |gu| Invitee.new(user: gu.user, post_id: self.id) }
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
          starts_at: event_params[:start] || event.starts_at,
          ends_at: event_params[:end],
          url: event_params[:url],
          recurrence: event_params[:recurrence],
          status:
            if event_params[:status].present?
              Event.statuses[event_params[:status].to_sym]
            else
              event.status
            end,
          reminders: event_params[:reminders],
          raw_invitees:
            if event_params[:"allowed-groups"]
              event_params[:"allowed-groups"].split(',')
            else
              nil
            end
        }

        event.update_with_params!(params)
      elsif post.event
        post.event.destroy!
      end
    end

    def missing_group_users
      GroupUser
        .joins(:group, :user)
        .where('groups.name' => self.raw_invitees)
        .where.not('users.id' => self.invitees.select(:user_id))
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

    def refresh_ends_at_handlers!(ends_at_changes)
      new_ends_at = ends_at_changes[1]
      Jobs.cancel_scheduled_job(
        :discourse_post_event_event_ended,
        event_id: self.id
      )

      if new_ends_at
        if new_ends_at > Time.now
          Jobs.enqueue_at(
            new_ends_at,
            :discourse_post_event_event_ended,
            event_id: self.id
          )
        else
          DiscourseEvent.trigger(:discourse_post_event_event_ended, self)
        end
      end
    end

    def refresh_starts_at_handlers!(starts_at_changes)
      new_starts_at = starts_at_changes[1]

      Jobs.cancel_scheduled_job(
        :discourse_post_event_event_started,
        event_id: self.id
      )
      Jobs.cancel_scheduled_job(
        :discourse_post_event_event_will_start,
        event_id: self.id
      )

      if new_starts_at > Time.now
        Jobs.enqueue_at(
          new_starts_at,
          :discourse_post_event_event_started,
          event_id: self.id
        )

        will_start_at = new_starts_at - 1.hour
        if will_start_at > Time.now
          Jobs.enqueue_at(
            will_start_at,
            :discourse_post_event_event_will_start,
            event_id: self.id
          )
        end
      end
    end

    def refresh_reminders!
      (self.reminders || '').split(',').map do |reminder|
        value, unit = reminder.split('.')

        if transaction_include_any_action?(%i[update])
          Jobs.cancel_scheduled_job(
            :discourse_post_event_send_reminder,
            event_id: self.id, reminder: reminder
          )
        end

        enqueue_at = self.starts_at - value.to_i.send(unit)
        if enqueue_at > Time.now
          Jobs.enqueue_at(
            enqueue_at,
            :discourse_post_event_send_reminder,
            event_id: self.id, reminder: reminder
          )
        end
      end
    end
  end
end
