# frozen_string_literal: true

require 'rails_helper'

describe DiscourseCalendar::UpdateHolidayUsernames do
  let(:calendar_post) { create_post(raw: "[calendar]\n[/calendar]") }

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.holiday_calendar_topic_id = calendar_post.topic_id
  end

  it "adds users on holiday to the users_on_holiday list" do
    raw = 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
    post = create_post(raw: raw, topic: calendar_post.topic)

    freeze_time Time.utc(2018, 6, 5, 18, 40)
    subject.execute(nil)

    expect(DiscourseCalendar.users_on_holiday).to eq([post.user.username])

    freeze_time Time.utc(2018, 6, 7, 18, 40)
    subject.execute(nil)

    expect(DiscourseCalendar.users_on_holiday).to eq([])
  end

  it "adds custom field to users on holiday" do
    raw1 = 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
    post1 = create_post(raw: raw1, topic: calendar_post.topic)

    raw2 = 'Rome [date="2018-06-05"]' # the whole day
    post2 = create_post(raw: raw2, topic: calendar_post.topic)

    freeze_time Time.utc(2018, 6, 5, 10, 30)
    subject.execute(nil)
    expect(UserCustomField.exists?(name: DiscourseCalendar::HOLIDAY_CUSTOM_FIELD, user_id: post1.user.id)).to be_truthy
    expect(UserCustomField.exists?(name: DiscourseCalendar::HOLIDAY_CUSTOM_FIELD, user_id: post2.user.id)).to be_truthy

    freeze_time Time.utc(2018, 6, 6, 10, 00)
    subject.execute(nil)
    expect(UserCustomField.exists?(name: DiscourseCalendar::HOLIDAY_CUSTOM_FIELD, user_id: post1.user.id)).to be_truthy
    expect(UserCustomField.exists?(name: DiscourseCalendar::HOLIDAY_CUSTOM_FIELD, user_id: post2.user.id)).to be_falsey

    freeze_time Time.utc(2018, 6, 7, 10, 00)
    subject.execute(nil)
    expect(UserCustomField.exists?(name: DiscourseCalendar::HOLIDAY_CUSTOM_FIELD, user_id: post1.user.id)).to be_falsey
    expect(UserCustomField.exists?(name: DiscourseCalendar::HOLIDAY_CUSTOM_FIELD, user_id: post2.user.id)).to be_falsey
  end
end
