require 'rails_helper'

describe DiscourseCalendar::CalendarUpdater do
  before do
    SiteSetting.queue_jobs = false
  end

  it "will correctly update the calendar" do
    post = create_post

    expect(post.custom_fields).to eq({})

    DiscourseCalendar::CalendarUpdater.update(post)

    expect(post.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD]).to eq("dynamic")
    expect(post.custom_fields[DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD]).to eq({})

    post.calendar_details = { "type" => "static" }

    DiscourseCalendar::CalendarUpdater.update(post)

    expect(post.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD]).to eq("static")
  end
end
