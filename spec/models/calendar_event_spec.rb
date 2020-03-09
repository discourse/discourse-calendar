# frozen_string_literal: true

require 'rails_helper'

describe CalendarEvent do
  let(:op) { op = create_post(raw: "[calendar]\n[/calendar]") }

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.all_day_event_start_time = ""
    SiteSetting.all_day_event_end_time = ""
  end

  it "will correctly update the associated first post calendar details" do
    expect(op.reload.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD]).to eq("dynamic")
    expect(CalendarEvent.where(topic_id: op.topic_id).count).to eq(0)

    raw = %{Rome [date="2018-06-05" time="10:20:00"]}
    post = create_post(raw: raw, topic: op.topic)

    calendar_event = CalendarEvent.find_by(post_id: post.id)
    expect(calendar_event.description).to eq("Rome")
    expect(calendar_event.start_date).to eq("2018-06-05T10:20:00Z")
    expect(calendar_event.end_date).to eq("2018-06-05T11:20:00Z")
    expect(calendar_event.username).to eq(post.user.username_lower)
  end

  it "will correctly remove the event if post doesn’t contain dates anymore" do
    raw = %{Rome [date="2018-06-05" time="10:20:00"]}
    post = create_post(raw: raw, topic: op.topic)

    expect(CalendarEvent.find_by(post_id: post.id)).to be_present

    post.update(raw: "Not sure about the dates anymore")
    CookedPostProcessor.new(post).post_process

    expect(CalendarEvent.find_by(post_id: post.id)).not_to be_present
  end

  it "will work with no time date" do
    raw = %{Rome [date="2018-06-05"] [date="2018-06-11"]}
    post = create_post(raw: raw, topic: op.topic)

    calendar_event = CalendarEvent.find_by(post_id: post.id)
    expect(calendar_event.start_date).to eq("2018-06-05T00:00:00Z")
    expect(calendar_event.end_date).to eq("2018-06-11T00:00:00Z")
  end

  it "will work with timezone" do
    raw = %{Rome [date="2018-06-05" timezone="Europe/Paris"] [date="2018-06-11" time="13:45:33" timezone="America/Los_Angeles"]}
    post = create_post(raw: raw, topic: op.topic)

    calendar_event = CalendarEvent.find_by(post_id: post.id)
    expect(calendar_event.start_date).to eq("2018-06-05T00:00:00+02:00")
    expect(calendar_event.end_date).to eq("2018-06-11T13:45:33-07:00")
  end

  it "will validate a post with more than two dates if not a calendar" do
    op = create_post(raw: "This is a tets of a topic")

    raw = %{Rome [date="2018-06-05" timezone="Europe/Paris"] [date="2018-06-11" time="13:45:33" timezone="America/Los_Angeles"] [date="2018-06-05" timezone="Europe/Paris"]}
    post = create_post(raw: raw, topic: op.topic)

    expect(post).to be_valid
  end

  it "will not work if topic was deleted" do
    raw = %{Rome [date="2018-06-05" time="10:20:00"]}
    post = create_post(raw: raw, topic: op.topic)

    PostDestroyer.new(Discourse.system_user, post).destroy
    PostDestroyer.new(Discourse.system_user, op).destroy

    PostDestroyer.new(Discourse.system_user, post.reload).recover
    expect(post.deleted_at).to eq(nil)
  end

  describe "all day event site settings" do
    before do
      SiteSetting.all_day_event_start_time = "06:30"
      SiteSetting.all_day_event_end_time = "18:00"
    end

    it "will work with no time date" do
      raw = %{Rome [date="2018-06-05"] [date="2018-06-11"]}
      post = create_post(raw: raw, topic: op.topic)

      calendar_event = CalendarEvent.find_by(post_id: post.id)
      expect(calendar_event.start_date).to eq("2018-06-05T06:30:00Z")
      expect(calendar_event.end_date).to eq("2018-06-11T18:00:00Z")
    end

    it "will work with timezone" do
      raw = %{Rome [date="2018-06-05" timezone="Europe/Paris"] [date="2018-06-11" time="13:45:33" timezone="America/Los_Angeles"]}
      post = create_post(raw: raw, topic: op.topic)

      event = CalendarEvent.find_by(post_id: post.id)
      expect(event.start_date).to eq("2018-06-05T06:30:00+02:00")
      expect(event.end_date).to eq("2018-06-11T13:45:33-07:00")
    end
  end

  context "#destroy" do
    it "removes event when a post is deleted" do
      post = create_post(raw: %{Some Event [date="2019-09-10"]}, topic: op.topic)

      expect(CalendarEvent.find_by(post_id: post.id)).to be_present

      PostDestroyer.new(Discourse.system_user, post).destroy

      expect(CalendarEvent.find_by(post_id: post.id)).to_not be_present
    end
  end
end
