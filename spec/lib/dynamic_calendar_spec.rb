require 'rails_helper'

describe 'Dynamic calendar' do
  raw = <<~MD
    [calendar]
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

  describe 'single date events' do
    it 'creates an entry in the calendar' do
      raw = <<~MD
        Rome [date="2018-06-05" timezone="Europe/Paris"]
      MD

      post = create_calendar_post(topic, raw)

      expect(topic.first_post.custom_fields["calendar-details"][post.post_number.to_s]).to eq([
        "Rome", "2018-06-05T00:00:00+02:00", nil, post.user.username
      ])
    end

    describe 'with time' do
      it 'creates an entry in the calendar' do
        raw = <<~MD
          Rome [date="2018-06-05" time="10:00:00" timezone="Europe/Paris"]
        MD

        post = create_calendar_post(topic, raw)

        expect(topic.first_post.custom_fields["calendar-details"][post.post_number.to_s]).to eq([
          "Rome", "2018-06-05T10:00:00+02:00", nil, post.user.username
        ])
      end
    end
  end

  describe 'range date events' do
    it 'creates an entry in the calendar' do
      raw = <<~MD
        Rome [date="2018-06-05" timezone="Europe/Paris"] → [date="2018-06-08" timezone="Europe/Paris"]
      MD

      post = create_calendar_post(topic, raw)

      expect(topic.first_post.custom_fields["calendar-details"][post.post_number.to_s]).to eq([
        "Rome", "2018-06-05T00:00:00+02:00", "2018-06-08T23:59:59+02:00", post.user.username
      ])
    end
  end

  describe 'more than two dates' do
    it 'raises an error' do
      raw = <<~MD
        Rome [date="2018-06-05" timezone="Europe/Paris"] → [date="2018-06-08" timezone="Europe/Paris"] [date="2018-06-09" timezone="Europe/Paris"]
      MD

      expect { create_calendar_post(topic, raw) }.to raise_error(StandardError, I18n.t("discourse_calendar.more_than_two_dates"))
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

  describe 'going from dynamic to static' do
    it 'cleans up everything' do
      raw = <<~MD
        Rome [date="2018-06-05" timezone="Europe/Paris"]
      MD

      post = create_calendar_post(topic, raw)
      expect(topic.first_post.custom_fields["calendar-details"][post.post_number.to_s]).to be_present

      raw = <<~MD
        [calendar type="static"]
        [/calendar]
      MD
      op.revise(op.user, raw: raw)
      op.reload

      expect(op.custom_fields['calendar']).to eq('static')
      expect(op.custom_fields['calendar-details']).to be_empty
    end
  end
end
