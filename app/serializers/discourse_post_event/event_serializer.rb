# frozen_string_literal: true

module DiscoursePostEvent
  class EventSerializer < ApplicationSerializer
    attributes :id
    attributes :creator
    attributes :sample_invitees
    attributes :watching_invitee
    attributes :starts_at
    attributes :ends_at
    attributes :stats
    attributes :status
    attributes :raw_invitees
    attributes :post
    attributes :name
    attributes :can_act_on_event
    attributes :can_update_attendance
    attributes :is_expired
    attributes :should_display_invitees

    def can_act_on_event
      scope.can_act_on_event?(object)
    end

    def is_expired
      object.is_expired?
    end

    def status
      Event.statuses[object.status]
    end

    # lightweight post object containing
    # only needed info for client
    def post
      {
        id: object.post.id,
        post_number: object.post.post_number,
        url: object.post.url,
        topic: {
          id: object.post.topic.id,
          title: object.post.topic.title
        }
      }
    end

    def can_update_attendance
      object.can_user_update_attendance(scope.current_user)
    end

    def creator
      BasicUserSerializer.new(object.post.user, embed: :objects, root: false)
    end

    def stats
      counts = object.invitees.group(:status).count

      # event creator is always going so we add one
      going = (counts[Invitee.statuses[:going]] || 0) + (object.is_expired? ? 0 : 1)
      interested = counts[Invitee.statuses[:interested]] || 0
      not_going = counts[Invitee.statuses[:not_going]] || 0
      unanswered = counts[nil] || 0

      {
        going: going,
        interested: interested,
        not_going: not_going,
        invited: going + interested + not_going + unanswered
      }
    end

    def watching_invitee
      if scope.current_user === object.post.user
        watching_invitee = Invitee.new(
          user_id: object.post.user.id,
          status: Invitee.statuses[:going],
          post_id: object.id
        )
      else
        watching_invitee = Invitee.find_by(
          user_id: scope.current_user.id,
          post_id: object.id
        )
      end

      if watching_invitee
        InviteeSerializer.new(watching_invitee, root: false)
      end
    end

    def sample_invitees
      invitees = object.most_likely_going(scope.current_user)
      ActiveModel::ArraySerializer.new(invitees, each_serializer: InviteeSerializer)
    end

    def should_display_invitees
      object.status != Event.statuses[:standalone]
    end
  end
end
