# frozen_string_literal: true

require "rails_helper"

describe "Static calendar" do
  let(:calendar_post) { create_post(raw: '[calendar type="static"]\n[/calendar]') }

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
  end

  it "can be created" do
    expect(calendar_post.reload.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD]).to eq("static")
  end

  it "can be revised to be dynamic" do
    calendar_post.revise(calendar_post.user, raw: "[calendar type='dynamic']\n[/calendar]")
    expect(calendar_post.reload.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD]).to eq("dynamic")
  end
end
