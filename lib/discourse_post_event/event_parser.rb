# frozen_string_literal: true

EVENT_REGEX = /\[wrap=event\s(.*?)\]/m
EVENT_OPTIONS_REGEX = /(\w+\=".*?")/m

VALID_OPTIONS = [
  :start,
  :end,
  :status,
  :allowedGroups,
  :name
]

module DiscoursePostEvent
  class EventParser
    def self.extract_events(str)
      str.scan(EVENT_REGEX).map do |scan|
        extract_options(scan[0].gsub(/\\/, ''))
      end.compact
    end

    def self.extract_options(str)
      options = nil
      str.scan(EVENT_OPTIONS_REGEX).each do |option|
        key, value = option[0].split("=")
        if VALID_OPTIONS.include?(key.to_sym) && value
          options ||= {}
          options[key.to_sym] = value.delete('\\"')
        end
      end
      options
    end
  end
end
