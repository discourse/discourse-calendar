# frozen_string_literal: true

VALID_OPTIONS = [
  :start,
  :end,
  :status,
  :"allowed-groups",
  :name
]

module DiscoursePostEvent
  class EventParser
    def self.extract_events(post)
      cooked = PrettyText.cook(post.raw, topic_id: post.topic_id, user_id: post.user_id)
      valid_options = VALID_OPTIONS.map { |o| "data-#{o}" }

      Nokogiri::HTML(cooked).css('[data-wrap="event"]').map do |doc|
        event = nil
        doc.attributes.values.each do |attribute|
          name = attribute.name
          value = attribute.value

          if valid_options.include?(name) && value
            event ||= {}
            event[name["data-".length..-1].to_sym] = CGI.escapeHTML(value)
          end
        end
        event
      end.compact
    end
  end
end
