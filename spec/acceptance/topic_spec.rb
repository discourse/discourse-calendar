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
    context 'with a date in title' do
      it 'doesn’t create a post event' do
        post_with_date = PostCreator.create!(
          user,
          title: 'Let’s buy a boat with me tomorrow',
          raw: 'The boat market is quite active lately.'
        )

        expect(Event).to_not exist(id: post_with_date.id)
      end
    end
  end
end
