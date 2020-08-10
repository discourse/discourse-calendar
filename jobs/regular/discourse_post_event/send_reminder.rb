# frozen_string_literal: true

module Jobs
  class DiscoursePostEventSendReminder < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      raise Discourse::InvalidParameters.new(:event_id) if args[:event_id].blank?
      raise Discourse::InvalidParameters.new(:reminder) if args[:reminder].blank?

      event = Event.includes(post: [:topic], invitees: [:user]).find(args[:event_id])
      invitees = event.invitees

      unread_notified_user_ids = Notification.where(
        read: false,
        notification_type: Notification.types[:custom],
        topic_id: event.post.topic_id,
        post_number: 1
      ).pluck(:user_id)

      invitees
        .where(status: DiscoursePostEvent::Invitee.statuses[:going])
        .where.not(user_id: unread_notified_user_ids)
        .find_each do |invitee|
        invitee.user.notifications.create!(
          notification_type: Notification.types[:custom],
          topic_id: event.post.topic_id,
          post_number: event.post.post_number,
          data: {
            topic_title: event.post.topic.title,
            display_username: invitee.user.username,
            message: 'discourse_post_event.notifications.before_event_reminder'
          }.to_json
        )
      end
    end
  end
end
