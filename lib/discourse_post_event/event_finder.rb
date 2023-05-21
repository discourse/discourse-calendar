# frozen_string_literal: true

module DiscoursePostEvent
  class EventFinder
    def self.search(user, params = {})
      guardian = Guardian.new(user)
      topics = listable_topics(guardian)
      pms = private_messages(user)

      # Commun data SQL query
      events = DiscoursePostEvent::Event
        .select("discourse_post_event_events.*, dcped.starts_at")
        .joins(post: :topic)
        .merge(Post.secured(guardian))
        .merge(topics.or(pms).distinct)
        .joins("LEFT JOIN discourse_calendar_post_event_dates dcped ON dcped.event_id = discourse_post_event_events.id")
        .order("dcped.starts_at ASC")

      # Filter events after this date
      if params[:after]
        events = events.where("dcped.starts_at >= ? OR dcped.ends_at >= ? ", params[:after], params[:after])
      end

      # Filter events before this date
      if params[:before]
        events = events.where("dcped.ends_at <= ? OR (dcped.ends_at IS NULL AND dcped.starts_at <= ?)", params[:before], params[:before])
      end

      # All events deleted
      events = events.where("dcped.deleted_at IS NULL")

      if params[:expired]

        # Filter the expired events
        events = events
          .where("dcped.finished_at IS NOT NULL AND (dcped.ends_at IS NOT NULL AND dcped.ends_at < ?)", Time.now)
          .where("discourse_post_event_events.id NOT IN (SELECT DISTINCT event_id FROM discourse_calendar_post_event_dates WHERE event_id = discourse_post_event_events.id AND finished_at IS NULL)")
      else
        # Only future events
        if not SiteSetting.show_past_events
          events = events.where("(dcped.ends_at IS NOT NULL AND dcped.ends_at > ?) OR (dcped.ends_at IS NULL AND dcped.starts_at > ?)", Time.now,  Time.now)
        end
      end

      #
      if params[:post_id]
        events = events.where(id: Array(params[:post_id]))
      end

      # Filter events from sategory
      if params[:category_id].present?
        # And sub categories
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
