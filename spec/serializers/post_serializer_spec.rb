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

end
