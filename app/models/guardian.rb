# frozen_string_literal: true

class ::Guardian
  module CanActOnPostEvent
    def can_act_on_post_event?(post_event)
      @user.staff? || @user.admin? || @user.id == post_event.post.user_id
    end
  end
  prepend CanActOnPostEvent

  module CanJoinPostEvent
    def can_join_post_event?(post_event)
      post_event.status === DiscourseCalendar::PostEvent.statuses[:public] || (
        post_event.status === DiscourseCalendar::PostEvent.statuses[:private]
        post_event.invitees.find_by(user_id: @user.id)
      )
    end
  end
  prepend CanJoinPostEvent
end
