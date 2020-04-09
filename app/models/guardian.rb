# frozen_string_literal: true

class ::Guardian
  module CanActOnEvent
    def can_act_on_event?(event)
      @user.staff? || @user.admin? || @user.id == event.post.user_id
    end
  end
  prepend CanActOnEvent

  module CanActOnInvitee
    def can_act_on_invitee?(invitee)
      @user.staff? || @user.admin? || @user.id == invitee.user_id
    end
  end
  prepend CanActOnInvitee

  module CanCreateEvent
    def can_create_event?(event)
      @user.staff? || @user.admin?
    end
  end
  prepend CanCreateEvent

  module CanJoinEvent
    def can_join_post_event?(event)
      event.status === DiscoursePostEvent::Event.statuses[:public] || (
        event.status === DiscoursePostEvent::Event.statuses[:private]
        event.invitees.find_by(user_id: @user.id)
      )
    end
  end
  prepend CanJoinEvent
end
