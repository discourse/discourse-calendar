# frozen_string_literal: true

module DiscoursePostEvent
  module PostExtension
    def self.prepended(base)
      base.class_eval do
        has_one :event,
                dependent: :destroy,
                class_name: "DiscoursePostEvent::Event",
                foreign_key: :id

        validate :valid_event
      end
    end

    def valid_event
      return unless self.raw_changed?

      validator = DiscoursePostEvent::EventValidator.new(self)
      validator.validate_event
    end
  end
end
