# frozen_string_literal: true

require "rails_helper"

describe Topic do
  Event ||= DiscoursePostEvent::Event

  before do
    freeze_time
    SiteSetting.queue_jobs = false
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  let(:user) { Fabricate(:user) }

  context 'when a topic is created' do
    context 'with a date' do
      it 'creates a post event' do
        post_with_date = PostCreator.create!(
          user,
          title: 'Let’s buy a boat with me tomorrow',
          raw: 'The boat market is quite active lately.'
        )

        post_event = Event.find(post_with_date.id)
        expect(post_event).to be_present
        expect(post_event.starts_at).to eq_time(post_with_date.topic.created_at.tomorrow.beginning_of_day)
        expect(post_event.status).to eq(Event.statuses[:standalone])
      end
    end
  end
end
