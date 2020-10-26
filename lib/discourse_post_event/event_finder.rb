# frozen_string_literal: true

module DiscoursePostEvent
  class EventFinder
    def self.search(user, params = {})
      guardian = Guardian.new(user)
      topics = listable_topics(guardian)
      pms = private_messages(user)

      if params[:expired]
        event_ids = DiscoursePostEvent::EventDate.expired.order(starts_at: :asc).pluck(:event_id)
        events = DiscoursePostEvent::Event.where.not(id: event_ids)
      else
        event_ids = DiscoursePostEvent::EventDate.not_expired.order(starts_at: :asc).pluck(:event_id)
        events = DiscoursePostEvent::Event.where(id: event_ids)
      end

      if params[:post_id]
        events = events.where(id: Array(params[:post_id]))
      end

      events = events.joins(post: :topic)
        .merge(Post.secured(guardian))
        .merge(topics.or(pms).distinct)
        .joins("LEFT JOIN discourse_calendar_post_event_dates dcped ON dcped.event_id = discourse_post_event_events.id")

      if params[:category_id].present?
        if params[:include_subcategories].present?
          events = events.where(topics: { category_id: Category.subcategory_ids(params[:category_id].to_i) })
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
