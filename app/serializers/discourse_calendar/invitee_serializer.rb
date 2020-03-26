# frozen_string_literal: true

module DiscourseCalendar
  class InviteeSerializer < ApplicationSerializer
    attributes :id, :status, :user

    def status
      object.status ? Invitee.statuses[object.status] : nil
    end

    def include_id?
      object.id
    end

    def user
      BasicUserSerializer.new(object.user, embed: :objects, root: false)
    end
  end
end
