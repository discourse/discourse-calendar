# frozen_string_literal: true

module DiscoursePostEvent
  class InviteeListSerializer < ApplicationSerializer
    root false
    attributes :meta
    has_many :invitees, serializer: InviteeSerializer, embed: :objects

    def invitees
      object[:invitees]
    end

    def meta
      {
        possible_invitees:
          ActiveModel::ArraySerializer.new(
            possible_invitees,
            each_serializer: BasicUserSerializer,
            scope: scope,
          ),
      }
    end

    def include_meta?
      possible_invitees.present?
    end

    def possible_invitees
      object[:possible_invitees]
    end
  end
end
