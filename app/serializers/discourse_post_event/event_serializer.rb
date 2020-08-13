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
    attributes :can_act_on_discourse_post_event
    attributes :can_update_attendance
    attributes :is_expired
    attributes :should_display_invitees
    attributes :url
    attributes :custom_fields
    attributes :is_public
    attributes :is_private
    attributes :is_standalone
    attributes :reminders
    attributes :recurrence

    def can_act_on_discourse_post_event
      scope.can_act_on_discourse_post_event?(object)
    end

    def reminders
      (object.reminders || '').split(',').map do |reminder|
        value, unit = reminder.split('.')
        value = value.to_i
        { value: value.to_i.abs, unit: unit, period: value > 0 ? 'before' : 'after' }
      end
    end

    def is_expired
      object.is_expired?
    end

    def is_public
      object.status === Event.statuses[:public]
    end

    def is_private
      object.status === Event.statuses[:private]
    end

    def is_standalone
      object.status === Event.statuses[:standalone]
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
      scope.current_user && object.can_user_update_attendance(scope.current_user)
    end

    def creator
      BasicUserSerializer.new(object.post.user, embed: :objects, root: false)
    end

    def stats
      counts = object.invitees.group(:status).count

      # event creator is always going so we add one
      going = counts[Invitee.statuses[:going]] || 0
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
      if scope.current_user
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
      invitees = object.most_likely_going
      ActiveModel::ArraySerializer.new(invitees, each_serializer: InviteeSerializer)
    end

    def should_display_invitees
      (object.public? && object.invitees.count > 0) || (object.private? && object.raw_invitees.count > 0)
    end
  end
end
