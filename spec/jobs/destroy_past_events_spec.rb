# frozen_string_literal: true

require "rails_helper"

describe DiscourseCalendar::DestroyPastEvents do
  let(:op) { create_post(raw: "[calendar]\n[/calendar]") }

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true

    expect(CalendarEvent.where(topic_id: op.topic_id).count).to eq(0)

    raw = 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="11:20:00"]'
    @post = create_post(raw: raw, topic: op.topic)
  end

  it "will correctly remove the post number from calendar details" do
    freeze_time Time.strptime("2018-06-03 09:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")

    DiscourseCalendar::DestroyPastEvents.new.execute(nil)

    calendar_event = CalendarEvent.find_by(post_id: @post.id)
    expect(calendar_event.description).to eq("Rome  to")
    expect(calendar_event.start_date).to eq("2018-06-05T10:20:00Z")
    expect(calendar_event.end_date).to eq("2018-06-06T11:20:00Z")
    expect(calendar_event.username).to eq(@post.user.username_lower)
    expect(calendar_event.recurrence).to eq(nil)

    freeze_time Time.strptime("2018-06-06 13:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")

    DiscourseCalendar::DestroyPastEvents.new.execute(nil)

    expect(CalendarEvent.find_by(post_id: @post.id)).to be_nil
  end

  it "will correctly destroy the post" do
    freeze_time Time.strptime("2018-06-06 13:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    DiscourseCalendar::DestroyPastEvents.new.execute(nil)
    expect(Post.find_by(id: @post.id)).to eq(nil)
  end

  context "when the post has direct replies" do
    let!(:direct_reply_without_event) do
      raw = 'Boy that sure sounds like fun, I wish I was going on vacation as well!'
      reply = create_post(raw: raw, topic: op.topic, reply_to_post_number: @post.post_number)
      PostReply.create(post: @post, reply: reply)
    end

    let!(:direct_reply_with_event) do
      raw = 'Rome [date="2018-06-07" time="10:20:00"] to [date="2018-06-08" time="11:20:00"]'
      reply = create_post(raw: raw, topic: op.topic, reply_to_post_number: @post.post_number)
      PostReply.create(post: @post, reply: reply)
    end

    before do
      freeze_time Time.strptime("2018-06-06 13:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
      DiscourseCalendar::DestroyPastEvents.new.execute(nil)
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
    @post = create_post(raw: raw, topic: op.topic)

    DiscourseCalendar::DestroyPastEvents.new.execute(nil)

    calendar_event = CalendarEvent.find_by(post_id: @post.id)
    expect(calendar_event.description).to eq("Rome  to")
    expect(calendar_event.start_date).to eq("2018-06-05T10:20:00Z")
    expect(calendar_event.end_date).to eq("2018-06-06T11:20:00Z")
    expect(calendar_event.username).to eq(@post.user.username_lower)
    expect(calendar_event.recurrence).to eq("1.weeks")

    freeze_time Time.strptime("2018-06-06 13:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    DiscourseCalendar::DestroyPastEvents.new.execute(nil)

    expect(CalendarEvent.find_by(post_id: @post.id)).to_not be_nil
  end
end
