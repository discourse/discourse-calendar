# frozen_string_literal: true

require 'rails_helper'

describe DiscourseCalendar::UpdateHolidayUsernames do
  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true

    @op = create_post(raw: "[calendar]\n[/calendar]")
    SiteSetting.holiday_calendar_topic_id = @op.topic_id
  end

  it "works" do
    raw = 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'

    post = create_post(raw: raw, topic: @op.topic)
    CookedPostProcessor.new(post).post_process

    freeze_time Time.utc(2018, 6, 5, 18, 40)
    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)

    expect(DiscourseCalendar.users_on_holiday).to eq([post.user.username])

    freeze_time Time.utc(2018, 6, 7, 18, 40)
    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)

    expect(DiscourseCalendar.users_on_holiday).to eq([])
  end
end
