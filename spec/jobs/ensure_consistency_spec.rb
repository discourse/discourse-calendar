# frozen_string_literal: true

require "rails_helper"

describe DiscourseCalendar::EnsureConsistency do
  before { SiteSetting.calendar_enabled = true }

  it "works" do
    op = create_post(raw: "[calendar]\n[/calendar]")

    SiteSetting.holiday_calendar_topic_id = op.topic_id

    post = create_post(raw: "Some Event [date=2019-09-10]", topic: op.topic)
    CookedPostProcessor.new(post).post_process

    op.reload
    expect(op.calendar_details[post.post_number.to_s]).to be_present

    DiscourseCalendar::EnsureConsistency.new.execute(nil)

    op.reload
    expect(op.calendar_details[post.post_number.to_s]).to be_present

    PostMover
      .new(op.topic, Discourse.system_user, [post.id])
      .to_new_topic("A topic with some dates in it")

    DiscourseCalendar::EnsureConsistency.new.execute(nil)

    op.reload
    expect(op.calendar_details).to eq({})
  end
end
