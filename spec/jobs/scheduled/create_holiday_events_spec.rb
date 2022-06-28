# frozen_string_literal: true

require 'rails_helper'

describe DiscourseCalendar::CreateHolidayEvents do
  let(:calendar_post) { create_post(raw: "[calendar]\n[/calendar]") }

  let(:frenchy) { Fabricate(:user, custom_fields: { DiscourseCalendar::REGION_CUSTOM_FIELD => "fr" }) }
  let(:aussie) { Fabricate(:user, custom_fields: { DiscourseCalendar::REGION_CUSTOM_FIELD => "au" }) }

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.holiday_calendar_topic_id = calendar_post.topic_id
  end

  it "adds all holidays in the next 6 months" do
    frenchy
    freeze_time Time.zone.local(2019, 8, 1)
    subject.execute(nil)

    expect(CalendarEvent.pluck(:region, :description, :start_date, :username)).to eq([
      ["fr", "Assomption", "2019-08-15", frenchy.username],
      ["fr", "Toussaint", "2019-11-01", frenchy.username],
      ["fr", "Armistice 1918", "2019-11-11", frenchy.username],
      ["fr", "Noël", "2019-12-25", frenchy.username],
      ["fr", "Jour de l'an", "2020-01-01", frenchy.username]
    ])
  end

  it "checks for observed dates" do
    aussie
    freeze_time Time.zone.local(2020, 1, 20)
    subject.execute(nil)

    # The "Australia Day" is always observed on a Monday
    expect(CalendarEvent.pluck(:region, :description, :start_date, :username)).to eq([
      ["au", "Australia Day", "2020-01-27", aussie.username],
      ["au", "Good Friday", "2020-04-10", aussie.username],
      ["au", "Easter Monday", "2020-04-13", aussie.username]
    ])
  end

  it "only checks for holidays during business days" do
    frenchy
    freeze_time Time.zone.local(2019, 7, 1)
    subject.execute(nil)

    # The "Fête Nationale" is on July 14th but it's on a Sunday in 2019
    expect(CalendarEvent.pluck(:region, :description, :start_date, :username)).to eq([
      ["fr", "Assomption", "2019-08-15", frenchy.username],
      ["fr", "Toussaint", "2019-11-01", frenchy.username],
      ["fr", "Armistice 1918", "2019-11-11", frenchy.username],
      ["fr", "Noël", "2019-12-25", frenchy.username],
      ["fr", "Jour de l'an", "2020-01-01", frenchy.username]
    ])
  end

  it "only takes into account active users" do
    freeze_time Time.zone.local(2019, 8, 1)

    robot = Fabricate(:user, id: -100, custom_fields: { DiscourseCalendar::REGION_CUSTOM_FIELD => "fr" })
    inactive = Fabricate(:user, active: false, custom_fields: { DiscourseCalendar::REGION_CUSTOM_FIELD => "fr" })
    suspended = Fabricate(:user, suspended_till: 1.year.from_now, custom_fields: { DiscourseCalendar::REGION_CUSTOM_FIELD => "fr" })
    silenced = Fabricate(:user, silenced_till: 1.year.from_now, custom_fields: { DiscourseCalendar::REGION_CUSTOM_FIELD => "fr" })

    subject.execute(nil)

    expect(CalendarEvent.pluck(:region, :description, :start_date, :username)).to eq([])
  end

  it "cleans up holidays from deactivated/silenced/suspended users" do
    frenchy
    freeze_time Time.zone.local(2019, 8, 1)
    subject.execute(nil)

    expect(CalendarEvent.exists?(username: frenchy.username)).to eq(true)

    frenchy.active = false
    frenchy.save!

    subject.execute(nil)

    expect(CalendarEvent.exists?(username: frenchy.username)).to eq(false)
  end

  context "when there are disabled holidays" do
    let(:france_assomption) { { holiday_name: "Assomption", region_code: "fr" } }
    let(:france_toussaint) { { holiday_name: "Toussaint", region_code: "fr" } }

    before do
      DiscourseCalendar::DisabledHoliday.create!(france_assomption)
      DiscourseCalendar::DisabledHoliday.create!(france_toussaint)
    end

    it "only adds enabled holidays to the calendar" do
      frenchy
      freeze_time Time.zone.local(2019, 7, 1)
      subject.execute(nil)

      expect(CalendarEvent.pluck(:region, :description, :start_date, :username)).to eq([
        ["fr", "Armistice 1918", "2019-11-11", frenchy.username],
        ["fr", "Noël", "2019-12-25", frenchy.username],
        ["fr", "Jour de l'an", "2020-01-01", frenchy.username]
      ])
    end

    it "doesn't add disabled holidays to the calendar" do
      frenchy
      freeze_time Time.zone.local(2019, 7, 1)
      subject.execute(nil)

      expect(CalendarEvent.pluck(:description)).not_to include(france_assomption[:holiday_name])
      expect(CalendarEvent.pluck(:description)).not_to include(france_toussaint[:holiday_name])
    end
  end

  context "when user_options.timezone column exists" do
    it "uses the user TZ when available" do
      frenchy.user_option.update!(timezone: "Europe/Paris")
      freeze_time Time.zone.local(2019, 8, 1)
      subject.execute(nil)

      calendar_event = CalendarEvent.first
      expect(calendar_event.region).to eq("fr")
      expect(calendar_event.description).to eq("Assomption")
      expect(calendar_event.start_date).to eq("2019-08-15T00:00:00+02:00")
      expect(calendar_event.username).to eq(frenchy.username)
    end

    describe "with all day event start and end time" do
      before do
        SiteSetting.all_day_event_start_time = "06:00"
        SiteSetting.all_day_event_end_time = "18:00"
      end

      it "uses the user TZ when available" do
        frenchy.user_option.update!(timezone: "Europe/Paris")
        freeze_time Time.zone.local(2019, 8, 1)
        subject.execute(nil)

        calendar_event = CalendarEvent.first
        expect(calendar_event.region).to eq("fr")
        expect(calendar_event.description).to eq("Assomption")
        expect(calendar_event.start_date).to eq("2019-08-15T06:00:00+02:00")
        expect(calendar_event.username).to eq(frenchy.username)
      end
    end
  end
end
