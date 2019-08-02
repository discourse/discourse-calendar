# frozen_string_literal: true

require 'rails_helper'

describe DiscourseCalendar::CheckNextRegionalHolidays do

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true

    @op = create_post(raw: "[calendar]\n[/calendar]")
    SiteSetting.holiday_calendar_topic_id = @op.topic_id
  end

  it "works" do
    frenchy = Fabricate(:user)
    frenchy.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "fr"
    frenchy.save!

    freeze_time Time.new(2019, 8, 1)

    subject.execute(nil)
    @op.reload

    expect(@op.calendar_holidays).to eq([
      ["fr", "Assomption", "2019-08-15", frenchy.username]
    ])
  end

  it "only checks for holidays during business days" do
    frenchy = Fabricate(:user)
    frenchy.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "fr"
    frenchy.save!

    freeze_time Time.new(2019, 7, 1)

    subject.execute(nil)
    @op.reload

    # The "Fête Nationale" is on July 14th but it's on a Sunday in 2019
    expect(@op.calendar_holidays).to eq([])
  end

  it "only checks for holidays within the current year" do
    frenchy = Fabricate(:user)
    frenchy.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "fr"
    frenchy.save!

    freeze_time Time.new(2019, 12, 29)

    subject.execute(nil)
    @op.reload

    # We don't want 2020/1/1
    expect(@op.calendar_holidays).to eq([])
  end

  it "uses the user TZ when available" do
    frenchy = Fabricate(:user)
    frenchy.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "fr"
    frenchy.custom_fields[DiscourseCalendar::TIMEZONE_CUSTOM_FIELD] = "Europe/Paris"
    frenchy.save!

    freeze_time Time.new(2019, 8, 1)

    subject.execute(nil)
    @op.reload

    expect(@op.calendar_holidays).to eq([
      ["fr", "Assomption", "2019-08-15T00:00:00+02:00", frenchy.username]
    ])
  end

  it "only takes into account active users" do
    freeze_time Time.new(2019, 8, 1)

    robot = Fabricate(:user, id: -100)
    robot.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "fr"
    robot.save!

    inactive = Fabricate(:user, active: false)
    inactive.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "fr"
    inactive.save!

    suspended = Fabricate(:user, suspended_till: 1.year.from_now)
    suspended.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "fr"
    suspended.save!

    silenced = Fabricate(:user, silenced_till: 1.year.from_now)
    silenced.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "fr"
    silenced.save!

    subject.execute(nil)
    @op.reload

    expect(@op.calendar_holidays).to eq([])
  end

end
