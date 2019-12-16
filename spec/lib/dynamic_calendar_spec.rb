# frozen_string_literal: true

require "rails_helper"

describe "Dynamic calendar" do

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
  end

  let(:raw) { "[calendar]\n[/calendar]" }
  let(:op) { create_post(raw: raw) }

  it "defaults to dynamic" do
    expect(op.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD]).to eq("dynamic")
  end

  it "adds an entry with a single date event" do
    p = create_post(topic: op.topic, raw: 'Rome [date="2018-06-05" timezone="Europe/Paris"]')

    op.reload
    expect(op.calendar_details[p.post_number.to_s]).to eq([
      "Rome", "2018-06-05T06:00:00+02:00", nil, p.user.username, nil
    ])
  end

  it "adds an entry with a single date/time event" do
    p = create_post(topic: op.topic, raw: 'Rome [date="2018-06-05" time="12:34:56"]')

    op.reload
    expect(op.calendar_details[p.post_number.to_s]).to eq([
      "Rome", "2018-06-05T12:34:56Z", nil, p.user.username, nil
    ])
  end

  it "adds an entry with a range event" do
    p = create_post(topic: op.topic, raw: 'Rome [date="2018-06-05" timezone="Europe/Paris"] → [date="2018-06-08" timezone="Europe/Paris"]')

    op.reload
    expect(op.calendar_details[p.post_number.to_s]).to eq([
      "Rome", "2018-06-05T06:00:00+02:00", "2018-06-08T18:00:00+02:00", p.user.username, nil
    ])
  end

  it "raises an error when there are more than 2 dates" do
    expect {
      create_post(topic: op.topic, raw: 'Rome [date="2018-06-05"] → [date="2018-06-08"] [date="2018-06-09"]')
    }.to raise_error(StandardError, I18n.t("discourse_calendar.more_than_two_dates"))
  end

  it "raises an error when the calendar is not in first post" do
    expect {
      create_post(topic: op.topic, raw: raw)
    }.to raise_error(StandardError, I18n.t("discourse_calendar.calendar_must_be_in_first_post"))
  end

  it "raises an error when there are more than 1 calendar" do
    expect {
      create_post(raw: "#{raw}\n#{raw}")
    }.to raise_error(StandardError, I18n.t("discourse_calendar.more_than_one_calendar"))
  end

  it "empties details when going from dynamic to static" do
    p = create_post(topic: op.topic, raw: 'Rome [date="2018-06-05"]')

    op.reload
    expect(op.calendar_details[p.post_number.to_s]).to be_present

    op.revise(op.user, raw: '[calendar type="static"]\n[/calendar]')

    op.reload
    expect(op.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD]).to eq("static")
    expect(op.calendar_details).to be_empty
  end

end
