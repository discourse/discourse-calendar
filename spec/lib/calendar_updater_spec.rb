require 'rails_helper'

describe DiscourseSimpleCalendar::CalendarUpdater do
  before do
    SiteSetting.queue_jobs = false
  end

  it "will correctly update the calendar" do
    post = create_post

    expect(post.custom_fields).to eq({})

    DiscourseSimpleCalendar::CalendarUpdater.update(post)

    expect(post.custom_fields[DiscourseSimpleCalendar::CALENDAR_CUSTOM_FIELD]).to eq("dynamic")
    expect(post.custom_fields[DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD]).to eq({})

    post.calendar_details = { "type" => "static" }

    DiscourseSimpleCalendar::CalendarUpdater.update(post)

    expect(post.custom_fields[DiscourseSimpleCalendar::CALENDAR_CUSTOM_FIELD]).to eq("static")
  end
end
