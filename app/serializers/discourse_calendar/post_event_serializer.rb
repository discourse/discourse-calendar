# frozen_string_literal: true

module DiscourseCalendar
  class PostEventSerializer < ApplicationSerializer
    attributes :id
    attributes :creator
    attributes :sample_invitees
    attributes :watching_invitee
    attributes :starts_at
    attributes :ends_at
    attributes :stats
    attributes :status
    attributes :raw_invitees
    attributes :display_invitees
    attributes :post
    attributes :should_display_invitees
    attributes :name
    attributes :can_act_on_post_event
    attributes :can_update_attendance

    def can_act_on_post_event
      scope.can_act_on_post_event?(object)
    end

    def status
      PostEvent.statuses[object.status]
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

    def should_display_invitees
      display_invitees?
    end

    def can_update_attendance
      object.can_user_update_attendance(scope.current_user)
    end

    def display_invitees
      PostEvent.display_invitees_options[object.display_invitees]
    end

    def creator
      BasicUserSerializer.new(object.post.user, embed: :objects, root: false)
    end

    def include_stats?
      display_invitees?
    end

    def stats
      counts = object.invitees.group(:status).count

      # event creator is always going so we add one
      going = (counts[Invitee.statuses[:going]] || 0) + 1
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

    def include_sample_invitees?
      display_invitees?
    end

    def sample_invitees
      invitees = object.most_likely_going(scope.current_user)
      ActiveModel::ArraySerializer.new(invitees, each_serializer: InviteeSerializer)
    end

    private

    def display_invitees?
      object.status != PostEvent.statuses[:standalone] &&
      (
        object.display_invitees == PostEvent.display_invitees_options[:everyone] ||
        (
          object.display_invitees == PostEvent.display_invitees_options[:invitees_only] &&
          object.invitees.exists?(user_id: scope.current_user.id)
        ) ||
        (
          object.display_invitees == PostEvent.display_invitees_options[:none] &&
          object.post.user == scope.current_user
        )
      )
    end
  end
end
