require 'rails_helper'

describe DiscourseSimpleCalendar::EventUpdater do
  before do
    SiteSetting.queue_jobs = false
  end

  it "will correctly remove the event and destroy the associated post" do
    freeze_time

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

    op.reload
    post_number = post.post_number.to_s

    expect(post.deleted_at).to be_nil
    expect(op.custom_fields[DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD][post_number]).to be_present

    DiscourseSimpleCalendar::EnsuredExpiredEventDestruction.new.execute
    post.reload
    op.reload

    expect(post.deleted_at).to be_present
    expect(op.custom_fields[DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD][post_number]).to be_nil
  end
end
