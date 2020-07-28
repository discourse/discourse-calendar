# frozen_string_literal: true

module DiscoursePostEvent
  class EventFinder
    def self.search(user, params = {})
      guardian = Guardian.new(user)
      topics = listable_topics(guardian)
      pms = private_messages(user)

      events = DiscoursePostEvent::Event.visible

      if params[:expired]
        events = events.expired
      else
        events = events.not_expired
      end

      if params[:post_id]
        events = events.where(id: Array(params[:post_id]))
      end

      events = events.joins(post: :topic)
        .merge(Post.secured(guardian))
        .merge(topics.or(pms).distinct)
        .order(starts_at: :asc)

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
