# frozen_string_literal: true

Fabricator(:post_event, from: 'DiscourseCalendar::PostEvent') do
  post { |attrs| attrs[:post] }

  id { |attrs| attrs[:post].id }

  status { |attrs|
    attrs[:status] ?
    DiscourseCalendar::PostEvent.statuses[attrs[:status]] :
    DiscourseCalendar::PostEvent.statuses[:public]
  }
  starts_at { |attrs| attrs[:starts_at] || 1.day.from_now.iso8601 }
  ends_at { |attrs| attrs[:ends_at] }
end
