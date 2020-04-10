# frozen_string_literal: true

module DiscoursePostEvent
  class EventFinder
    def self.search(user, params = {})
      guardian = Guardian.new(user)
      topics = listable_topics(guardian)
      pms = private_messages(user)

      events = DiscoursePostEvent::Event
        .visible
        .not_expired

      if params[:post_id]
        events = events.where(id: Array(params[:post_id]))
      end

      events.joins(post: :topic)
        .merge(Post.secured(guardian))
        .merge(topics.or(pms).distinct)
        .order(starts_at: :asc)
    end

    private

    def self.listable_topics(guardian)
      Topic.listable_topics.secured(guardian)
    end

    def self.private_messages(user)
      Topic.private_messages_for_user(user)
    end
  end
end
