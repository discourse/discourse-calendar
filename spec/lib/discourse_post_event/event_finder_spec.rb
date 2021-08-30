# frozen_string_literal: true

require "rails_helper"
require_relative '../../fabricators/event_fabricator'

describe DiscoursePostEvent::EventFinder do
  let(:current_user) { Fabricate(:user) }
  let(:user) { Fabricate(:user) }

  subject { DiscoursePostEvent::EventFinder }

  before do
    Jobs.run_immediately!
    SiteSetting.discourse_post_event_enabled = true
  end

  context 'the event is associated to a visible post' do
    let(:post1) {
      PostCreator.create!(
        user,
        title: 'We should buy a boat',
        raw: 'The boat market is quite active lately.'
      )
    }
    let!(:event) { Fabricate(:event, post: post1) }

    it 'returns the event' do
      expect(subject.search(current_user)).to match_array([event])
    end
  end

  context 'the event is associated to a visible PM' do
    let(:post1) {
      PostCreator.create!(
        user,
        title: 'We should buy a boat',
        raw: 'The boat market is quite active lately.',
        archetype: Archetype.private_message,
        target_usernames: "#{current_user.username}"
      )
    }
    let!(:event) { Fabricate(:event, post: post1) }

    it 'returns the event' do
      expect(subject.search(current_user)).to match_array([event])
    end
  end

  context 'the event is associated to a not visible PM' do
    let(:another_user) { Fabricate(:user) }
    let(:post1) {
      PostCreator.create!(
        user,
        title: 'We should buy a boat',
        raw: 'The boat market is quite active lately.',
        archetype: Archetype.private_message,
        target_usernames: "#{another_user.username}"
      )
    }
    let!(:event) { Fabricate(:event, post: post1) }

    it 'doesn’t return the event' do
      expect(subject.search(current_user)).to match_array([])
    end
  end

  context 'events are filtered' do
    context 'by post_id' do
      let(:post1) {
        PostCreator.create!(
          user,
          title: 'We should buy a boat',
          raw: 'The boat market is quite active lately.'
        )
      }
      let(:post2) {
        PostCreator.create!(
          user,
          title: 'We should buy another boat',
          raw: 'The boat market is very active lately.'
        )
      }
      let!(:event1) { Fabricate(:event, post: post1) }
      let!(:event2) { Fabricate(:event, post: post2) }

      it 'returns only the specified event' do
        expect(subject.search(current_user, { post_id: post2.id })).to match_array([event2])
      end
    end

    context 'by expiration status' do
      let(:post1) {
        PostCreator.create!(
          user,
          title: 'We should buy a boat',
          raw: 'The boat market is quite active lately.'
        )
      }
      let(:post2) {
        PostCreator.create!(
          user,
          title: 'We should buy another boat',
          raw: 'The boat market is very active lately.'
        )
      }
      let!(:event1) { Fabricate(:event, post: post1, original_starts_at: 2.hours.ago, original_ends_at: 1.hour.ago) }
      let!(:event2) { Fabricate(:event, post: post2, original_starts_at: 1.hour.from_now, original_ends_at: 2.hours.from_now) }

      it 'returns non-expired events when false' do
        expect(subject.search(current_user, { expired: false })).to match_array([event2])
      end

      it 'returns expired events when true' do
        expect(subject.search(current_user, { expired: true })).to match_array([event1])
      end
    end
  end
end
