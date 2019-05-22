require 'rails_helper'

describe DiscourseCalendar::UpdateHolidayUsernames do
  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true

    @op = create_post(raw: "[calendar]\n[/calendar]")
    SiteSetting.holiday_calendar_topic_id = @op.topic_id
  end

  it "should update users on holiday list" do
    raw = 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
    post = create_post(raw: raw, topic: @op.topic)
    CookedPostProcessor.new(post).post_process

    freeze_time Time.strptime("2018-06-05 18:40:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)

    expect(DiscourseCalendar.users_on_holiday).to eq([post.user.username])
  end

  it "should have empty users on holiday list" do
    raw = 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
    post = create_post(raw: raw, topic: @op.topic)
    CookedPostProcessor.new(post).post_process

    freeze_time Time.strptime("2018-06-07 18:40:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)

    expect(DiscourseCalendar.users_on_holiday).to eq([])
  end
end
