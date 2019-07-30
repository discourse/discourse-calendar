# frozen_string_literal: true

require "rails_helper"

describe "Static calendar" do

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
  end

  let(:raw) { '[calendar type="static"]\n[/calendar]' }
  let(:op) { create_post(raw: raw) }

  it "is static" do
    expect(op.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD]).to eq("static")
  end

  it "empties details when going from static to dynamic" do
    p = create_post(topic: op.topic, raw: 'Rome [date="2018-06-05"]')

    op.reload
    expect(op.calendar_details[p.post_number.to_s]).to be_present

    op.revise(op.user, raw: "[calendar]\n[/calendar]")

    op.reload
    expect(op.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD]).to eq("dynamic")
    expect(op.calendar_details).to be_empty
  end

end
