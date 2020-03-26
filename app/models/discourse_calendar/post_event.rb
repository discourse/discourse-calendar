# frozen_string_literal: true

module DiscourseCalendar
  class PostEvent < ActiveRecord::Base
    self.table_name = 'discourse_calendar_post_events'

    def self.attributes_protected_by_default
      super - ['id']
    end

    has_many :invitees, foreign_key: :post_id, dependent: :delete_all
    belongs_to :post, foreign_key: :id

    scope :visible, -> { where(deleted_at: nil) }

    validates :name,
      length: { in: 5..30 },
      unless: -> (post_event) { post_event.name.blank? }

    validate :raw_invitees_length
    def raw_invitees_length
      if self.raw_invitees && self.raw_invitees.length > 10
        errors.add(:base, I18n.t("discourse_calendar.post_event.errors.raw_invitees_length", count: 10))
      end
    end

    validate :ends_before_start
    def ends_before_start
      if self.starts_at && self.ends_at && self.starts_at >= self.ends_at
        errors.add(:base, I18n.t("discourse_calendar.post_event.errors.ends_at_before_starts_at"))
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
        invitee.user.notifications.create!(
          notification_type: Notification.types[:custom],
          topic_id: self.post.topic_id,
          post_number: self.post.post_number,
          data: {
            topic_title: self.post.topic.title,
            display_username: self.post.user.username,
            message: 'discourse_calendar.invite_user_notification'
          }.to_json
        )
        invitee.update!(notified: true)
      end
    end

    def self.statuses
      @statuses ||= Enum.new(standalone: 0, public: 1, private: 2)
    end

    def self.display_invitees_options
      @display_invitees_options ||= Enum.new(everyone: 0, invitees_only: 1, none: 2)
    end

    def most_likely_going(current_user, limit = SiteSetting.displayed_invitees_limit)
      most_likely = []

      if current_user.id != self.post.user_id
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
      self.post.publish_message!("/post-events/#{self.post.topic_id}", id: self.id)
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
      @fetched_users ||= User.where(
        id: GroupUser.where(
          group_id: Group.where(name: self.raw_invitees).select(:id)
        ).select(:user_id)
      ).or(User.where(username: self.raw_invitees))
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
  end
end
