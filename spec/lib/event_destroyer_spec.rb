# frozen_string_literal: true

require "rails_helper"

describe DiscourseCalendar::EventDestroyer do

  before { SiteSetting.calendar_enabled = true }

  it "removes event when a post is deleted" do
    op = create_post(raw: "[calendar]\n[/calendar]")
    post = create_post(raw: %{Some Event [date="2019-09-10"]}, topic: op.topic)
    CookedPostProcessor.new(post).post_process

    op.reload
    expect(op.calendar_details[post.post_number.to_s]).to be_present

    PostDestroyer.new(Discourse.system_user, post).destroy

    op.reload
    expect(op.calendar_details[post.post_number.to_s]).to_not be_present
  end
end
