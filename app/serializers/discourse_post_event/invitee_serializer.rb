# frozen_string_literal: true

module DiscoursePostEvent
  class InviteeSerializer < ApplicationSerializer
    attributes :id, :status, :user, :post_id, :meta

    def status
      object.status ? Invitee.statuses[object.status] : nil
    end

    def include_id?
      object.id
    end

    def user
      BasicUserSerializer.new(object.user, embed: :objects, root: false)
    end

    def meta
      { event_stats: EventStatsSerializer.new(object.event, root: false) }
    end
  end
end
