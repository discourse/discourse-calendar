# frozen_string_literal: true

module DiscoursePostEvent
  class EventSummarySerializer < ApplicationSerializer
    attributes :id
    attributes :starts_at
    attributes :ends_at
    attributes :timezone
    attributes :post
    attributes :name
    attributes :category_id
    attributes :upcoming_dates

    # lightweight post object containing
    # only needed info for client
    def post
      {
        id: object.post.id,
        post_number: object.post.post_number,
        url: object.post.url,
        topic: {
          id: object.post.topic.id,
          title: object.post.topic.title,
        },
      }
    end

    def category_id
      object.post.topic.category_id
    end

    def include_upcoming_dates?
      object.recurring?
    end

    def upcoming_dates
      difference = object.original_ends_at ? object.original_ends_at - object.original_starts_at : 0

      RRuleGenerator
        .generate(
          object.starts_at.in_time_zone(object.timezone),
          tzid: object.timezone,
          max_years: 1,
          recurrence_type: object.recurrence,
        )
        .map { |date| { starts_at: date, ends_at: date + difference.seconds } }
    end
  end
end
