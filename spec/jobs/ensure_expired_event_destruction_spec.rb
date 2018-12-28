require 'rails_helper'

describe DiscourseCalendar::EnsuredExpiredEventDestruction do
  before do
    SiteSetting.queue_jobs = false

    raw = <<~MD
      [calendar]
      [/calendar]
    MD
    topic = Fabricate(:topic, first_post: create_post(raw: raw))
    @op = topic.first_post

    expect(@op.calendar_details).to eq({})

    raw = <<~MD
      Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="11:20:00"]
    MD

    @post = create_post(raw: raw, topic: topic)
    CookedPostProcessor.new(@post).post_process
  end

  it "will correctly remove the post number from calendar details" do
    freeze_time Time.strptime("2018-06-03 09:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    DiscourseCalendar::EnsuredExpiredEventDestruction.new.execute(nil)
    @op.reload

    expect(@op.calendar_details[@post.post_number.to_s]).to eq([
      "Rome  to", "2018-06-05T10:20:00Z", "2018-06-06T11:20:00Z", @post.user.username_lower
    ])

    freeze_time Time.strptime("2018-06-06 13:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    DiscourseCalendar::EnsuredExpiredEventDestruction.new.execute(nil)
    @op.reload

    expect(@op.calendar_details[@post.post_number.to_s]).to be_nil
  end

  it "wont destroy recurring events" do
    freeze_time Time.strptime("2018-06-03 09:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")

    raw = <<~MD
      Rome [date="2018-06-05" time="10:20:00" recurring="1.weeks"] to [date="2018-06-06" time="11:20:00"]
    MD
    @post = create_post(raw: raw, topic: @op.topic)
    CookedPostProcessor.new(@post).post_process

    DiscourseCalendar::EnsuredExpiredEventDestruction.new.execute(nil)
    @op.reload

    expect(@op.calendar_details[@post.post_number.to_s]).to eq([
      "Rome  to", "2018-06-05T10:20:00Z", "2018-06-06T11:20:00Z", @post.user.username_lower, "1.weeks"
    ])

    freeze_time Time.strptime("2018-06-06 13:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    DiscourseCalendar::EnsuredExpiredEventDestruction.new.execute(nil)
    @op.reload

    expect(@op.calendar_details[@post.post_number.to_s]).to_not be_nil
  end
end
