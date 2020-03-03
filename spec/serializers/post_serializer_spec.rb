# frozen_string_literal: true

require "rails_helper"

describe "post serializer" do

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
  end

  it "includes calendar details" do
    op = create_post(raw: "[calendar]\n[/calendar]")

    post = create_post(topic: op.topic, raw: 'Rome [date="2018-06-05" time="10:20:00"]')

    op.reload

    json = PostSerializer.new(op, scope: Guardian.new).as_json

    expect(json[:post][:calendar_details].size).to eq(1)
  end

  it "includes group timezones detail" do
    Fabricate(:admin)
    Group.refresh_automatic_groups!(:admins)

    op = create_post(raw: "[timezones group=\"admins\"]\n[/timezones]\n\n[timezones group=\"trust_level_0\"]\n[/timezones]")
    op.reload

    json = PostSerializer.new(op, scope: Guardian.new).as_json
    group_timezones = json[:post][:group_timezones]

    expect(group_timezones["admins"].count).to eq(1)
    expect(group_timezones["trust_level_0"].count).to eq(2)
  end

end
