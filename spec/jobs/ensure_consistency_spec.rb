# frozen_string_literal: true

require "rails_helper"

describe DiscourseCalendar::EnsureConsistency do
  let(:op) { create_post(raw: "[calendar]\n[/calendar]") }

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.holiday_calendar_topic_id = op.topic_id
  end

  it "works" do
    post = create_post(raw: "Some Event [date=2019-09-10]", topic: op.topic)

    expect(CalendarEvent.find_by(topic_id: op.topic_id, post_id: post.id)).to be_present

    DiscourseCalendar::EnsureConsistency.new.execute(nil)

    expect(CalendarEvent.find_by(topic_id: op.topic_id, post_id: post.id)).to be_present

    PostMover.new(op.topic, Discourse.system_user, [post.id])
      .to_new_topic("A topic with some dates in it")

    DiscourseCalendar::EnsureConsistency.new.execute(nil)

    expect(CalendarEvent.where(topic_id: op.topic_id).count).to eq(0)
  end
end
