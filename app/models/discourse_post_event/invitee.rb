# frozen_string_literal: true

module DiscoursePostEvent
  class Invitee < ActiveRecord::Base
    self.table_name = 'discourse_post_event_invitees'

    belongs_to :event, foreign_key: :post_id
    belongs_to :user

    scope :with_status, ->(status) {
      where(status: Invitee.statuses[status])
    }

    def self.statuses
      @statuses ||= Enum.new(going: 0, interested: 1, not_going: 2)
    end

    def update_attendance(params)
      self.update!(params)
    end

    def self.extract_uniq_usernames(user_and_groups_list)
      User.where(
        id: GroupUser.where(
          group_id: Group.where(name: user_and_groups_list).select(:id)
        ).select(:user_id)
      ).or(User.where(username: user_and_groups_list))
    end
  end
end
