require 'rails_helper'

describe 'markdown' do
  before do
    SiteSetting.queue_jobs = false
  end

  it "can properly decorate dynamic calendars" do
    raw = <<~MD
     [calendar]
     [/calendar]
    MD

    cooked = (<<~HTML).strip
      <div class="calendar" data-calendar-type="dynamic"></div>
    HTML

    expect(PrettyText.cook raw).to eq(cooked)
  end

  it "can properly decorate static calendars" do
    raw = <<~MD
     [calendar type="static"]
     [/calendar]
    MD

    cooked = (<<~HTML).strip
      <div class="calendar" data-calendar-type="static"></div>
    HTML

    expect(PrettyText.cook raw).to eq(cooked)
  end
end
