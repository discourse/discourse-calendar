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
  end
end
