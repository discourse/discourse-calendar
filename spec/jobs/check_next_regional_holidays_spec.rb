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

    freeze_time Time.zone.local(2019, 8, 1)

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

  it "checks for observed dates" do
    aussie = Fabricate(:user)
    aussie.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "au"
    aussie.save!

    freeze_time Time.zone.local(2020, 1, 20)

    subject.execute(nil)
    @op.reload

    # The "Australia Day" is always observed on a Monday
    expect(@op.calendar_holidays).to eq([
      ["au", "Australia Day", "2020-01-27", aussie.username],
      ["au", "Good Friday", "2020-04-10", aussie.username],
      ["au", "Easter Monday", "2020-04-13", aussie.username]
    ])
  end

  it "only checks for holidays during business days" do
    frenchy = Fabricate(:user)
    frenchy.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "fr"
    frenchy.save!

    freeze_time Time.zone.local(2019, 7, 1)

    subject.execute(nil)
    @op.reload

    # The "Fête Nationale" is on July 14th but it's on a Sunday in 2019
    expect(@op.calendar_holidays).to eq([
      ["fr", "Assomption", "2019-08-15", frenchy.username],
      ["fr", "Toussaint", "2019-11-01", frenchy.username],
      ["fr", "Armistice 1918", "2019-11-11", frenchy.username],
      ["fr", "Noël", "2019-12-25", frenchy.username],
      ["fr", "Jour de l'an", "2020-01-01", frenchy.username]
    ])
  end

  context "when user_options.timezone column exists" do
    it "uses the user TZ when available" do
      frenchy = Fabricate(:user)
      frenchy.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "fr"
      frenchy.user_option.timezone = "Europe/Paris"
      frenchy.user_option.save!
      frenchy.save!

      freeze_time Time.zone.local(2019, 8, 1)

      subject.execute(nil)
      @op.reload

      expect(@op.calendar_holidays[0]).to eq(
        ["fr", "Assomption", "2019-08-15T00:00:00+02:00", frenchy.username]
      )
    end

    describe "with all day event start and end time" do
      before do
        SiteSetting.all_day_event_start_time = "06:00"
        SiteSetting.all_day_event_end_time = "18:00"
      end

      it "uses the user TZ when available" do
        frenchy = Fabricate(:user)
        frenchy.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "fr"
        frenchy.user_option.timezone = "Europe/Paris"
        frenchy.user_option.save!
        frenchy.save!

        freeze_time Time.zone.local(2019, 8, 1)

        subject.execute(nil)
        @op.reload

        expect(@op.calendar_holidays[0]).to eq(
          ["fr", "Assomption", "2019-08-15T06:00:00+02:00", frenchy.username]
        )
      end
    end
  end

  it "only takes into account active users" do
    freeze_time Time.zone.local(2019, 8, 1)

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
