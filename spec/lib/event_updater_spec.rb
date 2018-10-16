require 'rails_helper'

describe DiscourseCalendar::EventUpdater do
  before do
    SiteSetting.queue_jobs = false
  end

  it "will correctly update the associated first post calendar details" do
    raw = <<~MD
      [calendar]
      [/calendar]
    MD
    topic = Fabricate(:topic, first_post: create_post(raw: raw))
    op = topic.first_post

    expect(op.calendar_details).to eq({})

    raw = <<~MD
      Rome [date="2018-06-05" time="10:20:00"]
    MD

    post = create_post(raw: raw, topic: topic)
    CookedPostProcessor.new(post).post_process

    op.reload

    expect(op.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD]).to eq("dynamic")
    expect(op.calendar_details).to eq({
      post.post_number.to_s => [
        "Rome", "2018-06-05T10:20:00Z", nil, post.user.username_lower
      ]
    })
  end

  it "will correctly remove the event if post doesn’t contain dates anymore" do
    raw = <<~MD
      [calendar]
      [/calendar]
    MD
    topic = Fabricate(:topic, first_post: create_post(raw: raw))

    op = topic.first_post

    raw = <<~MD
      Rome [date="2018-06-05" time="10:20:00"]
    MD
    post = create_post(raw: raw, topic: topic)
    CookedPostProcessor.new(post).post_process

    op.reload

    expect(op.calendar_details[post.post_number.to_s]).to be_present

    post.raw = "Not sure about the dates anymore"
    post.save
    CookedPostProcessor.new(post).post_process

    op.reload

    expect(op.calendar_details[post.post_number.to_s]).not_to be_present
  end

  it "will work with no time date" do
    raw = <<~MD
      [calendar]
      [/calendar]
    MD
    topic = Fabricate(:topic, first_post: create_post(raw: raw))

    op = topic.first_post

    raw = <<~MD
      Rome [date="2018-06-05"] [date="2018-06-11"]
    MD
    post = create_post(raw: raw, topic: topic)
    CookedPostProcessor.new(post).post_process

    op.reload

    detail = op.calendar_details[post.post_number.to_s]
    expect(detail[DiscourseCalendar::FROM_INDEX]).to eq("2018-06-05T00:00:00Z")
    expect(detail[DiscourseCalendar::TO_INDEX]).to eq("2018-06-11T23:59:59Z")
  end

  it "will work with timezone" do
    raw = <<~MD
      [calendar]
      [/calendar]
    MD
    topic = Fabricate(:topic, first_post: create_post(raw: raw))

    op = topic.first_post

    raw = <<~MD
      Rome [date="2018-06-05" timezone="Europe/Paris"] [date="2018-06-11" time="13:45:33" timezone="America/Los_Angeles"]
    MD
    post = create_post(raw: raw, topic: topic)
    CookedPostProcessor.new(post).post_process

    op.reload

    detail = op.calendar_details[post.post_number.to_s]
    expect(detail[DiscourseCalendar::FROM_INDEX]).to eq("2018-06-05T00:00:00+02:00")
    expect(detail[DiscourseCalendar::TO_INDEX]).to eq("2018-06-11T13:45:33-07:00")
  end
end
