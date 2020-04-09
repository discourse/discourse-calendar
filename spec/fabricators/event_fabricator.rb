# frozen_string_literal: true

Fabricator(:event, from: 'DiscoursePostEvent::Event') do
  post { |attrs| attrs[:post] }

  id { |attrs| attrs[:post].id }

  status { |attrs|
    attrs[:status] ?
    DiscoursePostEvent::Event.statuses[attrs[:status]] :
    DiscoursePostEvent::Event.statuses[:public]
  }
  starts_at { |attrs| attrs[:starts_at] || 1.day.from_now.iso8601 }
  ends_at { |attrs| attrs[:ends_at] }
end
