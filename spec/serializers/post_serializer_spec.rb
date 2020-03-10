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
end
