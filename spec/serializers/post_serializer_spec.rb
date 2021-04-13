# frozen_string_literal: true

require "rails_helper"

describe PostSerializer do
  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
  end

  it "includes calendar events" do
    calendar_post = create_post(raw: "[calendar]\n[/calendar]")

    post = create_post(topic: calendar_post.topic, raw: 'Rome [date="2018-06-05" time="10:20:00"]')

    json = PostSerializer.new(calendar_post, scope: Guardian.new).as_json
    expect(json[:post][:calendar_details].size).to eq(1)
  end

  it "includes group timezones" do
    Fabricate(:admin)
    Group.refresh_automatic_groups!(:admins)

    calendar_post = create_post(raw: "[timezones group=\"admins\"]\n[/timezones]\n\n[timezones group=\"trust_level_0\"]\n[/timezones]")

    json = PostSerializer.new(calendar_post.reload, scope: Guardian.new).as_json
    expect(json[:post][:group_timezones]["admins"].count).to eq(1)
    expect(json[:post][:group_timezones]["trust_level_0"].count).to eq(2)
  end

  it "groups calendar events correctly" do
    user = Fabricate(:user)
    user.upsert_custom_fields(::DiscourseCalendar::REGION_CUSTOM_FIELD => 'ar')

    post = create_post(raw: "[calendar]\n[/calendar]")
    SiteSetting.holiday_calendar_topic_id = post.topic.id

    freeze_time Date.new(2021, 4, 1)
    ::DiscourseCalendar::CreateHolidayEvents.new.execute({})

    json = PostSerializer.new(post.reload, scope: Guardian.new).as_json
    expect(json[:post][:calendar_details].map { |x| x[:name] }).to contain_exactly(
      "Día del Veterano y de los Caídos en la Guerra de Malvinas, Viernes Santo",
      "Día de la Revolución de Mayo",
      "Feriado puente turístico",
      "Día de la Independencia"
    )
    expect(json[:post][:calendar_details].map { |x| x[:usernames] }).to all (contain_exactly(user.username))
  end
end
