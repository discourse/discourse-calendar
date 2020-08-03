# frozen_string_literal: true

module DiscoursePostEvent
  class Invitee < ActiveRecord::Base
    UNKNOWN_ATTENDANCE = 'unknown'

    self.table_name = 'discourse_post_event_invitees'

    belongs_to :event, foreign_key: :post_id
    belongs_to :user

    default_scope {
      joins(:user)
        .includes(:user)
        .where('users.id IS NOT NULL')
    }

    scope :with_status, ->(status) {
      where(status: Invitee.statuses[status])
    }

    def self.statuses
      @statuses ||= Enum.new(going: 0, interested: 1, not_going: 2)
    end

    def self.create_attendance!(user_id, post_id, status)
      invitee = Invitee.create!(
        status: Invitee.statuses[status.to_sym],
        post_id: post_id,
        user_id: user_id,
      )
      invitee.event.publish_update!
      invitee
    end

    def update_attendance!(status)
      self.update(status: Invitee.statuses[status.to_sym])
      self.event.publish_update!
      self
    end

    def self.extract_uniq_usernames(groups)
      User.where(
        id: GroupUser.where(
          group_id: Group.where(name: groups).select(:id)
        ).select(:user_id)
      )
    end
  end
end
