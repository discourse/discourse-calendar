require 'rails_helper'

describe 'Dynamic calendar' do
  raw = <<~MD
    [calendar type="static"]
    [/calendar]
  MD
  let(:op) { create_post(raw: raw) }
  let(:topic) { op.topic }

  before do
    SiteSetting.queue_jobs = false
  end

  def create_calendar_post(topic, raw)
    post = create_post(raw: raw, topic: topic)
    topic.reload
    post.reload
    post
  end

  describe 'multiple calendars in one post' do
    it 'raises an error' do
      expect {
        raw = <<~MD
          [calendar type="static"]
          [/calendar]
          [calendar type="static"]
          [/calendar]
        MD
        post = create_post(raw: raw)
        Fabricate(:topic, first_post: post)
      }.to raise_error(StandardError, I18n.t("discourse_calendar.more_than_one_calendar"))
    end
  end

  describe 'going from static to dynamic' do
    it 'cleans up everything' do
      raw = <<~MD
        Rome [date="2018-06-05" timezone="Europe/Paris"]
      MD

      post = create_calendar_post(topic, raw)
      expect(topic.first_post.custom_fields["calendar-details"][post.post_number.to_s]).to be_present

      raw = <<~MD
        [calendar]
        [/calendar]
      MD
      op.revise(op.user, raw: raw)
      op.reload

      expect(op.custom_fields['calendar']).to eq('dynamic')
      expect(op.custom_fields['calendar-details']).to be_empty
    end
  end

  describe 'a calendar not in first post' do
    it 'raises an error' do
      raw = <<~MD
        Another calendar
        [calendar]
        [/calendar]
      MD

      expect { create_calendar_post(topic, raw) }.to raise_error(StandardError, I18n.t("discourse_calendar.calendar_must_be_in_first_post"))
    end
  end
end
