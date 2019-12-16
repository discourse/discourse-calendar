# frozen_string_literal: true

require 'rails_helper'

describe DiscourseCalendar::CheckNextRegionalHolidays do

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true

    @op = create_post(raw: "[calendar]\n[/calendar]")
    SiteSetting.holiday_calendar_topic_id = @op.topic_id
  end

  it "adds all holidays in the next 6 months" do
    frenchy = Fabricate(:user)
    frenchy.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "fr"
    frenchy.save!

    freeze_time Time.new(2019, 8, 1)

    subject.execute(nil)
    @op.reload

    expect(@op.calendar_holidays).to eq([
      ["fr", "Assomption", "2019-08-15", frenchy.username],
      ["fr", "Toussaint", "2019-11-01", frenchy.username],
      ["fr", "Armistice 1918", "2019-11-11", frenchy.username],
      ["fr", "Noël", "2019-12-25", frenchy.username],
      ["fr", "Jour de l'an", "2020-01-01", frenchy.username]
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
    expect(@op.calendar_holidays).to eq([
      ["fr", "Assomption", "2019-08-15", frenchy.username],
      ["fr", "Toussaint", "2019-11-01", frenchy.username],
      ["fr", "Armistice 1918", "2019-11-11", frenchy.username],
      ["fr", "Noël", "2019-12-25", frenchy.username]
    ])
  end

  context "when user_options.timezone column exists" do
    before do
      silence_warnings do
        DiscourseCalendar::USER_OPTIONS_TIMEZONE_ENABLED = true
      end
    end

    it "uses the user TZ when available" do
      frenchy = Fabricate(:user)
      frenchy.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "fr"
      frenchy.user_option.timezone = "Europe/Paris"
      frenchy.user_option.save!
      frenchy.save!

      freeze_time Time.new(2019, 8, 1)

      subject.execute(nil)
      @op.reload

      expect(@op.calendar_holidays[0]).to eq(
        ["fr", "Assomption", "2019-08-15T06:00:00+02:00", frenchy.username]
      )
    end
  end

  context "when user_options.timezone column does NOT exist" do
    before do
      silence_warnings do
        DiscourseCalendar::USER_OPTIONS_TIMEZONE_ENABLED = false
      end
    end

    it "uses the users custom fields" do
      frenchy = Fabricate(:user)
      frenchy.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "fr"
      frenchy.custom_fields[DiscourseCalendar::TIMEZONE_CUSTOM_FIELD] = "Europe/Paris"
      frenchy.save!

      freeze_time Time.new(2019, 8, 1)

      subject.execute(nil)
      @op.reload

      expect(@op.calendar_holidays[0]).to eq(
        ["fr", "Assomption", "2019-08-15T06:00:00+02:00", frenchy.username]
      )
    end
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
