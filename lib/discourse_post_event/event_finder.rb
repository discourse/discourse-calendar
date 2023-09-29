# frozen_string_literal: true

module DiscoursePostEvent
  class EventFinder
    def self.search(user, params = {})
      guardian = Guardian.new(user)
      topics = listable_topics(guardian)
      pms = private_messages(user)

      events =
        DiscoursePostEvent::Event
          .select("discourse_post_event_events.*, dcped.starts_at")
          .joins(post: [:user, { topic: {} }])
          .includes(post: { user: {}, topic: {} })
          .merge(Post.secured(guardian))
          .merge(topics.or(pms).distinct)
          .joins(
            "LEFT JOIN discourse_calendar_post_event_dates dcped ON dcped.event_id = discourse_post_event_events.id",
          )
          .order("dcped.starts_at ASC")

      if params[:expired]
        # The second part below makes the query ignore events that have non-expired event-dates
        events =
          events.where(
            "dcped.finished_at IS NOT NULL AND (dcped.ends_at IS NOT NULL AND dcped.ends_at < ?)",
            Time.now,
          ).where(
            "discourse_post_event_events.id NOT IN (SELECT DISTINCT event_id FROM discourse_calendar_post_event_dates WHERE event_id = discourse_post_event_events.id AND finished_at IS NULL)",
          )
      else
        events =
          events.where(
            "dcped.finished_at IS NULL AND (dcped.ends_at IS NULL OR dcped.ends_at > ?)",
            Time.now,
          )
      end

      events = events.where(id: Array(params[:post_id])) if params[:post_id]

      if params[:category_id].present?
        if params[:include_subcategories].present?
          events =
            events.where(
              topics: {
                category_id: Category.subcategory_ids(params[:category_id].to_i),
              },
            )
        else
          events = events.where(topics: { category_id: params[:category_id].to_i })
        end
      end

      events
    end

    private

    def self.listable_topics(guardian)
      Topic.listable_topics.secured(guardian)
    end

    def self.private_messages(user)
      user ? Topic.private_messages_for_user(user) : Topic.none
    end
  end
end
