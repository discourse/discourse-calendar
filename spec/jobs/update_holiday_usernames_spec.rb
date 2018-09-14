require 'rails_helper'

describe DiscourseSimpleCalendar::UpdateHolidayUsernames do
  before do
    SiteSetting.queue_jobs = false

    raw = <<~MD
      [calendar]
      [/calendar]
    MD
    @topic = Fabricate(:topic, first_post: create_post(raw: raw))
    SiteSetting.discourse_simple_calendar_holiday_post_id = @topic.first_post.id
  end

  it "should update users on holiday list" do
    raw = <<~MD
    Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]
    MD
    post = create_post(raw: raw, topic: @topic)
    CookedPostProcessor.new(post).post_process

    freeze_time Time.strptime("2018-06-05 18:40:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    DiscourseSimpleCalendar::UpdateHolidayUsernames.new.execute(nil)

    expect(DiscourseSimpleCalendar.users_on_holiday).to eq([post.user.username])
  end

  it "should have empty users on holiday list" do
    raw = <<~MD
    Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]
    MD
    post = create_post(raw: raw, topic: @topic)
    CookedPostProcessor.new(post).post_process

    freeze_time Time.strptime("2018-06-07 18:40:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    DiscourseSimpleCalendar::UpdateHolidayUsernames.new.execute(nil)

    expect(DiscourseSimpleCalendar.users_on_holiday).to eq([])
  end
end
