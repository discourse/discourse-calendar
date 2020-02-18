# frozen_string_literal: true

require "rails_helper"

describe "Group timezones" do

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
  end

  let(:raw) { '[timezones group="admins"]\n[/timezones]' }
  let(:op) { create_post(raw: raw) }

  it "converts the markdown to correct HTML" do
    expect(op.cooked).to match_html(<<~HTML)
      <div class="group-timezones" data-group="admins" data-size="medium">
      <p>\\n</p>
      </div>
    HTML
  end

  it "creates correct custom fields" do
    op.reload
    expect(op.has_group_timezones?).to eq(true)
    expect(op.group_timezones).to eq("groups" => ["admins"])
  end

end
