# frozen_string_literal: true

require "rails_helper"

describe DiscourseCalendar::UsersOnHoliday do
  it "returns users that are currently on holiday" do
    event1 = Fabricate(:calendar_event, start_date: "2000-01-01")
    event2 = Fabricate(:calendar_event, start_date: "2000-01-01")
    event3 = Fabricate(:calendar_event, start_date: "2000-01-01")
    event4 = Fabricate(:calendar_event, start_date: "2000-01-02")

    freeze_time Time.utc(2000, 1, 1, 8, 0)
    users_on_holiday = DiscourseCalendar::UsersOnHoliday.from([event1, event2, event3, event4])

    usernames = users_on_holiday.map { |u| u[:username] }
    expect(usernames).to contain_exactly(event1.username, event2.username, event3.username)
  end

  it "returns empty list if no one is currently on holiday" do
    event1 = Fabricate(:calendar_event, start_date: "2000-01-02")
    event2 = Fabricate(:calendar_event, start_date: "2000-01-02")
    event3 = Fabricate(:calendar_event, start_date: "2000-01-02")
    event4 = Fabricate(:calendar_event, start_date: "2000-01-02")

    freeze_time Time.utc(2000, 1, 1, 8, 0)
    users_on_holiday = DiscourseCalendar::UsersOnHoliday.from([event1, event2, event3, event4])

    expect(users_on_holiday).to be_empty
  end

  it "ignore events without usernames" do
    event1 = Fabricate(:calendar_event, start_date: "2000-01-01")
    event2 = Fabricate(:calendar_event, start_date: "2000-01-01")
    event3 = Fabricate(:calendar_event, start_date: "2000-01-01", username: nil)

    freeze_time Time.utc(2000, 1, 1, 8, 0)
    users_on_holiday = DiscourseCalendar::UsersOnHoliday.from([event1, event2, event3])

    usernames = users_on_holiday.map { |u| u[:username] }
    expect(usernames).to contain_exactly(event1.username, event2.username)
  end
end
