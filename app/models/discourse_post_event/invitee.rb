# frozen_string_literal: true

module DiscoursePostEvent
  class Invitee < ActiveRecord::Base
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

    def update_attendance(params)
      self.update!(params)
    end

    def self.upsert_attendance!(user_id, params, guardian)
      invitee = Invitee.find_by(id: user_id)
      status = Invitee.statuses[params[:status].to_sym]

      if invitee
        guardian.ensure_can_act_on_invitee!(invitee)
        invitee.update_attendance(status: status)
      else
        event = Event.find(params[:post_id])
        guardian.ensure_can_see!(event.post)
        invitee = Invitee.create!(
          status: status,
          post_id: params[:post_id],
          user_id: user_id,
        )
      end

      invitee.event.publish_update!
      invitee
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
