# frozen_string_literal: true

module DiscoursePostEvent
  class Event < ActiveRecord::Base
    self.table_name = 'discourse_post_event_events'

    def self.attributes_protected_by_default
      super - ['id']
    end

    after_commit :destroy_topic_custom_field, on: [:destroy]
    def destroy_topic_custom_field
      if self.post.is_first_post?
        TopicCustomField
          .where(
            topic_id: self.post.topic_id,
            name: TOPIC_POST_EVENT_STARTS_AT,
          )
          .delete_all
      end
    end

    after_commit :upsert_topic_custom_field, on: [:create, :update]
    def upsert_topic_custom_field
      if self.post.is_first_post?
        TopicCustomField
          .upsert({
            topic_id: self.post.topic_id,
            name: TOPIC_POST_EVENT_STARTS_AT,
            value: self.starts_at,
            created_at: Time.now,
            updated_at: Time.now,
          }, unique_by: [:name, :topic_id])
      end
    end

    has_many :invitees, foreign_key: :post_id, dependent: :delete_all
    belongs_to :post, foreign_key: :id

    scope :visible, -> { where(deleted_at: nil) }
    scope :not_expired, -> { where("starts_at > :now", now: Time.now) }

    validates :starts_at, presence: true

    validates :name,
      length: { in: 5..30 },
      unless: -> (event) { event.name.blank? }

    validate :raw_invitees_length
    def raw_invitees_length
      if self.raw_invitees && self.raw_invitees.length > 10
        errors.add(:base, I18n.t("discourse_post_event.errors.models.event.raw_invitees_length
", count: 10))
      end
    end

    validate :ends_before_start
    def ends_before_start
      if self.starts_at && self.ends_at && self.starts_at >= self.ends_at
        errors.add(:base, I18n.t("discourse_post_event.errors.models.event.ends_at_before_starts_at"))
      end
    end

    def create_invitees(attrs)
      timestamp = Time.now
      attrs.map! do |attr|
        {
          post_id: self.id,
          created_at: timestamp,
          updated_at: timestamp
        }.merge(attr)
      end

      self.invitees.insert_all!(attrs)
    end

    def notify_invitees!
      self.invitees.where(notified: false).each do |invitee|
        create_notification!(invitee.user, self.post)
        invitee.update!(notified: true)
      end
    end

    def create_notification!(user, post)
      user.notifications.create!(
        notification_type: Notification.types[:custom],
        topic_id: post.topic_id,
        post_number: post.post_number,
        data: {
          topic_title: post.topic.title,
          display_username: post.user.username,
          message: 'discourse_calendar.invite_user_notification'
        }.to_json
      )
    end

    def self.statuses
      @statuses ||= Enum.new(standalone: 0, public: 1, private: 2)
    end

    def self.display_invitees_options
      @display_invitees_options ||= Enum.new(everyone: 0, invitees_only: 1, none: 2)
    end

    def most_likely_going(current_user, limit = SiteSetting.displayed_invitees_limit)
      most_likely = []

      if self.can_user_update_attendance(current_user)
        most_likely << Invitee.find_or_initialize_by(
          user_id: current_user.id,
          post_id: self.id
        )
      end

      most_likely << Invitee.new(
        user_id: self.post.user_id,
        status: Invitee.statuses[:going],
        post_id: self.id
      )

      most_likely + self.invitees
        .order([:status, :user_id])
        .where.not(user_id: current_user.id)
        .limit(limit - most_likely.count)
    end

    def publish_update!
      self.post.publish_message!("/discourse-post-event/#{self.post.topic_id}", id: self.id)
    end

    def destroy_extraneous_invitees!
      self.invitees.where.not(user_id: fetch_users.select(:id)).delete_all
    end

    def fill_invitees!
      invited_users_ids = fetch_users.pluck(:id) - self.invitees.pluck(:user_id)
      if invited_users_ids.present?
        self.create_invitees(invited_users_ids.map { |user_id|
          { user_id: user_id }
        })
      end
    end

    def fetch_users
      @fetched_users ||= Invitee.extract_uniq_usernames(self.raw_invitees)
    end

    def enforce_raw_invitees!
      self.destroy_extraneous_invitees!
      self.fill_invitees!
      self.notify_invitees!
    end

    def enforce_utc!(params)
      if params['starts_at'].present?
        params['starts_at'] = Time.parse(params['starts_at']).utc
      end
      if params['ends_at'].present?
        params['ends_at'] = Time.parse(params['ends_at']).utc
      end
    end

    def can_user_update_attendance(user)
      !self.is_expired? &&
      self.post.user != user &&
      (
        self.status == Event.statuses[:public] ||
        (
          self.status == Event.statuses[:private] &&
          self.invitees.exists?(user_id: user.id)
        )
      )
    end

    def is_expired?
      Time.now > (self.ends_at || self.starts_at || Time.now)
    end

    def display_invitees?(current_user)
      !self.is_expired? &&
      self.status != Event.statuses[:standalone] &&
      (
        self.display_invitees == Event.display_invitees_options[:everyone] ||
        (
          self.display_invitees == Event.display_invitees_options[:invitees_only] &&
          self.invitees.exists?(user_id: current_user.id)
        ) ||
        (
          self.display_invitees == Event.display_invitees_options[:none] &&
          self.post.user == current_user
        )
      )
    end
  end
end
