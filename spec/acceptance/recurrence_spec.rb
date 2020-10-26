# frozen_string_literal: true

require 'rails_helper'

require_relative '../fabricators/event_fabricator'

describe 'discourse_post_event_recurrence' do
  let(:user_1) { Fabricate(:user, admin: true) }
  let(:topic_1) { Fabricate(:topic, user: user_1) }
  let(:post_1) { Fabricate(:post, topic: topic_1) }
  let(:starts_at) { Time.zone.parse('2020-09-10 19:00') }
  let(:post_event_1) { Fabricate(:event, post: post_1, original_starts_at: starts_at, original_ends_at: starts_at + 1.hour) }

  before do
    freeze_time(starts_at)

    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  context 'every_month' do
    before do
      post_event_1.update!(recurrence: 'every_month')
    end

    it 'sets the next month at the same weekday' do
      post_event_1.set_next_date

      expect(post_event_1.starts_at).to eq_time(Time.zone.parse('2020-10-08 19:00'))
    end
  end

  context 'every_week' do
    before do
      post_event_1.update!(recurrence: 'every_week')
    end

    it 'sets the next week at the same weekday' do
      post_event_1.set_next_date

      expect(post_event_1.starts_at).to eq_time(Time.zone.parse('2020-09-17 19:00'))
    end
  end

  context 'every_day' do
    before do
      post_event_1.update!(recurrence: 'every_day')
    end

    it 'sets the next day' do
      post_event_1.set_next_date

      expect(post_event_1.starts_at).to eq_time(Time.zone.parse('2020-09-11 19:00'))
    end
  end

  context 'every_weekday' do
    before do
      post_event_1.update!(
        original_starts_at: Time.zone.parse('2020-09-11 19:00'),
        original_ends_at: Time.zone.parse('2020-09-11 19:00') + 1.hour,
        recurrence: 'every_weekday'
      )
    end

    it 'sets the next day' do
      freeze_time(post_event_1.original_starts_at)
      post_event_1.set_next_date

      expect(post_event_1.starts_at).to eq_time(Time.zone.parse('2020-09-14 19:00'))
    end
  end
end
