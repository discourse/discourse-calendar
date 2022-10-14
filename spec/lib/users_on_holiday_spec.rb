# frozen_string_literal: true

require "rails_helper"

describe DiscourseCalendar::UsersOnHoliday do
  it "returns users on holiday" do
    event1 = Fabricate(:calendar_event, start_date: "2000-01-01")
    event2 = Fabricate(:calendar_event, start_date: "2000-01-01")
    event3 = Fabricate(:calendar_event, start_date: "2000-01-01")
    event4 = Fabricate(:calendar_event, start_date: "2000-01-02")

    freeze_time Time.utc(2000, 1, 1, 8, 0)
    users_on_holiday = DiscourseCalendar::UsersOnHoliday.from([event1, event2, event3, event4])

    usernames = users_on_holiday.values.map { |u| u[:username] }
    expect(usernames).to contain_exactly(event1.username, event2.username, event3.username)
  end

  it "returns empty list if no one is on holiday" do
    event1 = Fabricate(:calendar_event, start_date: "2000-01-02")
    event2 = Fabricate(:calendar_event, start_date: "2000-01-03")
    event3 = Fabricate(:calendar_event, start_date: "2000-01-04")
    event4 = Fabricate(:calendar_event, start_date: "2000-01-05")

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

    usernames = users_on_holiday.values.map { |u| u[:username] }
    expect(usernames).to contain_exactly(event1.username, event2.username)
  end

  it "chooses the holiday with the biggest end date if user has several holidays" do
    user = Fabricate(:user)
    biggest_end_date = "2000-01-04"
    event1 = Fabricate(:calendar_event, user: user, start_date: "2000-01-01", end_date: "2000-01-02")
    event2 = Fabricate(:calendar_event, user: user, start_date: "2000-01-01", end_date: "2000-01-03")
    event3 = Fabricate(:calendar_event, user: user, start_date: "2000-01-01", end_date: biggest_end_date)

    freeze_time Time.utc(2000, 1, 1, 8, 0)
    users_on_holiday = DiscourseCalendar::UsersOnHoliday.from([event1, event2, event3])

    expect(users_on_holiday.length).to be(1)
    expect(users_on_holiday.values[0][:ends_at]).to eq(biggest_end_date)
  end
end
