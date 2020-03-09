# frozen_string_literal: true

module Jobs
  class ::DiscourseCalendar::DestroyPastEvents < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      return unless SiteSetting.calendar_enabled

      delay = SiteSetting.delete_expired_event_posts_after
      return if delay < 0

      events = CalendarEvent
        .includes(:post)
        .joins(:topic)
        .where("NOT topics.closed AND NOT topics.archived")

      expired_event_ids = Set.new
      event_post_ids = events.pluck(:post_id).to_set

      events.each do |event|
        next if event.recurrence
        end_date = event.end_date ? event.end_date : event.start_date + 24.hours
        next if end_date + delay.hour > Time.zone.now
        next if event.post.blank?

        expired_event_ids << event.id

        # Delete the post and all replies that do not represent other events
        event.post.replies.each do |reply|
          destroy_post(reply) if !event_post_ids.include?(reply.id)
        end

        destroy_post(event.post)
      end

      CalendarEvent.where(id: expired_event_ids).destroy_all
    end

    def destroy_post(post)
      PostDestroyer.new(Discourse.system_user, post).destroy
    end
  end
end
