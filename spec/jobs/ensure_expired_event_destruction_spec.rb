# frozen_string_literal: true

require "rails_helper"

describe DiscourseCalendar::EnsuredExpiredEventDestruction do
  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true

    @op = create_post(raw: "[calendar]\n[/calendar]")
    expect(@op.calendar_details).to eq({})

    raw = 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="11:20:00"]'
    @post = create_post(raw: raw, topic: @op.topic)
    CookedPostProcessor.new(@post).post_process
  end

  it "will correctly remove the post number from calendar details" do
    freeze_time Time.strptime("2018-06-03 09:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    DiscourseCalendar::EnsuredExpiredEventDestruction.new.execute(nil)
    @op.reload

    expect(@op.calendar_details[@post.post_number.to_s]).to eq([
      "Rome  to", "2018-06-05T10:20:00Z", "2018-06-06T11:20:00Z", @post.user.username_lower, nil, "/t/-/#{@post.topic.id}/#{@post.post_number}"
    ])

    freeze_time Time.strptime("2018-06-06 13:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    DiscourseCalendar::EnsuredExpiredEventDestruction.new.execute(nil)
    @op.reload

    expect(@op.calendar_details[@post.post_number.to_s]).to be_nil
  end

  it "will correctly destroy the post" do
    freeze_time Time.strptime("2018-06-06 13:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    DiscourseCalendar::EnsuredExpiredEventDestruction.new.execute(nil)
    expect(Post.find_by(id: @post.id)).to eq(nil)
  end

  context "when the post has direct replies" do
    let!(:direct_reply_without_event) do
      raw = 'Boy that sure sounds like fun, I wish I was going on vacation as well!'
      reply = create_post(raw: raw, topic: @op.topic, reply_to_post_number: @post.post_number)
      PostReply.create(post: @post, reply: reply)
    end
    let!(:direct_reply_with_event) do
      raw = 'Rome [date="2018-06-07" time="10:20:00"] to [date="2018-06-08" time="11:20:00"]'
      reply = create_post(raw: raw, topic: @op.topic, reply_to_post_number: @post.post_number)
      PostReply.create(post: @post, reply: reply)
    end

    before do
      freeze_time Time.strptime("2018-06-06 13:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
      DiscourseCalendar::EnsuredExpiredEventDestruction.new.execute(nil)
    end

    it "destroys replies without events (small talk)" do
      expect(Post.find_by(id: direct_reply_without_event.id)).to eq(nil)
    end

    it "does not destroy replies with events" do
      expect(Post.find_by(id: direct_reply_with_event.id)).to eq(nil)
    end
  end

  it "wont destroy recurring events" do
    freeze_time Time.strptime("2018-06-03 09:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")

    raw = 'Rome [date="2018-06-05" time="10:20:00" recurring="1.weeks"] to [date="2018-06-06" time="11:20:00"]'
    @post = create_post(raw: raw, topic: @op.topic)
    CookedPostProcessor.new(@post).post_process

    DiscourseCalendar::EnsuredExpiredEventDestruction.new.execute(nil)
    @op.reload

    expect(@op.calendar_details[@post.post_number.to_s]).to eq([
      "Rome  to", "2018-06-05T10:20:00Z", "2018-06-06T11:20:00Z", @post.user.username_lower, "1.weeks", "/t/-/#{@post.topic.id}/#{@post.post_number}"
    ])

    freeze_time Time.strptime("2018-06-06 13:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    DiscourseCalendar::EnsuredExpiredEventDestruction.new.execute(nil)
    @op.reload

    expect(@op.calendar_details[@post.post_number.to_s]).to_not be_nil
  end
end
