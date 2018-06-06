require 'rails_helper'

describe DiscourseSimpleCalendar::EventUpdater do
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

    raw = <<~MD
      Rome [date="2018-06-05" time="10:20"]
    MD
    post = create_post(raw: raw, topic: topic)

    details = op.custom_fields[DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD]
    expect(details).to eq({})

    DiscourseSimpleCalendar::EventUpdater.update(post)
    op.reload

    details = op.custom_fields[DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD]
    expect(op.custom_fields[DiscourseSimpleCalendar::CALENDAR_CUSTOM_FIELD]).to eq("dynamic")
    expect(op.custom_fields[DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD]).to eq({
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
      Rome [date="2018-06-05" time="10:20"]
    MD
    post = create_post(raw: raw, topic: topic)

    DiscourseSimpleCalendar::EventUpdater.update(post)
    op.reload

    expect(op.custom_fields[DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD][post.post_number.to_s]).to be_present

    post.raw = "Not sure about the dates anymore"

    DiscourseSimpleCalendar::EventUpdater.update(post)
    op.reload

    expect(op.custom_fields[DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD][post.post_number.to_s]).not_to be_present
  end
end
