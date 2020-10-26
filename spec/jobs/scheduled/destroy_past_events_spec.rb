# frozen_string_literal: true

require "rails_helper"

describe DiscourseCalendar::DestroyPastEvents do
  let(:calendar_post) { create_post(raw: "[calendar]\n[/calendar]") }
  let(:post) { create_post(raw: 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="11:20:00"]', topic: calendar_post.topic) }

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
  end

  it "will correctly destroy the post" do
    expect(Post.find_by(id: post.id)).not_to eq(nil)

    freeze_time Time.strptime("2018-06-06 13:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    subject.execute(nil)

    expect(Post.find_by(id: post.id)).to eq(nil)
    expect(UserHistory.find_by(post_id: post.id).context).to eq(I18n.t("discourse_calendar.event_expired"))
  end

  it "will correctly destroy the calendar event" do
    freeze_time Time.strptime("2018-06-03 09:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")

    subject.execute(nil)

    calendar_event = CalendarEvent.find_by(post_id: post.id)
    expect(calendar_event.description).to eq("Rome  to")
    expect(calendar_event.start_date).to eq("2018-06-05T10:20:00Z")
    expect(calendar_event.end_date).to eq("2018-06-06T11:20:00Z")
    expect(calendar_event.username).to eq(post.user.username_lower)
    expect(calendar_event.recurrence).to eq(nil)

    freeze_time Time.strptime("2018-06-06 13:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    subject.execute(nil)

    expect(CalendarEvent.find_by(post_id: post.id)).to be_nil
  end

  it "will not destroy posts outside calendar events" do
    post = Fabricate(:post)
    CalendarEvent.create!(topic: post.topic, post: post, start_date: 10.years.ago)

    subject.execute(nil)

    expect(Post.find_by(id: post.id)).not_to eq(nil)
  end

  it "will destroy expired standalone events" do
    topic = Fabricate(:topic)
    event = CalendarEvent.create!(topic: calendar_post.topic, start_date: 10.years.ago)

    subject.execute(nil)

    expect(CalendarEvent.find_by(id: event.id)).to eq(nil)
  end

  it "will not destroy recurring events" do
    freeze_time Time.strptime("2018-06-03 09:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")

    raw = 'Rome [date="2018-06-05" time="10:20:00" recurring="1.weeks"] to [date="2018-06-06" time="11:20:00"]'
    post = create_post(raw: raw, topic: calendar_post.topic)

    subject.execute(nil)

    calendar_event = CalendarEvent.find_by(post_id: post.id)
    expect(calendar_event.description).to eq("Rome  to")
    expect(calendar_event.start_date).to eq("2018-06-05T10:20:00Z")
    expect(calendar_event.end_date).to eq("2018-06-06T11:20:00Z")
    expect(calendar_event.username).to eq(post.user.username_lower)
    expect(calendar_event.recurrence).to eq("1.weeks")

    freeze_time Time.strptime("2018-06-06 13:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
    subject.execute(nil)

    expect(CalendarEvent.find_by(post_id: post.id)).to_not be_nil
  end

  context "when the post has direct replies" do
    let!(:direct_reply_without_event) do
      raw = 'Boy that sure sounds like fun, I wish I was going on vacation as well!'
      create_post(raw: raw, topic: calendar_post.topic, reply_to_post_number: post.post_number)
    end

    let!(:direct_reply_with_event) do
      raw = 'Rome [date="2018-06-07" time="10:20:00"] to [date="2018-06-08" time="11:20:00"]'
      create_post(raw: raw, topic: calendar_post.topic, reply_to_post_number: post.post_number)
    end

    it "destroys only replies without events" do
      freeze_time Time.strptime("2018-06-06 13:21:00 UTC", "%Y-%m-%d %H:%M:%S %Z")
      subject.execute(nil)

      expect(Post.find_by(id: direct_reply_with_event.id)).not_to eq(nil)
      expect(Post.find_by(id: direct_reply_without_event.id)).to eq(nil)
    end
  end
end
