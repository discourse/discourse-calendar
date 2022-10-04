# frozen_string_literal: true
require "rails_helper"

describe DiscoursePostEvent::EventFinder do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:user) { Fabricate(:user) }

  subject { DiscoursePostEvent::EventFinder }

  before do
    Jobs.run_immediately!
    SiteSetting.discourse_post_event_enabled = true
    Group.refresh_automatic_groups!
  end

  context 'when the event is associated to a visible post' do
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

  context 'when the event is associated to a visible PM' do
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

  context 'when the event is associated to a not visible PM' do
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

  context 'when events are filtered' do
    describe 'by post_id' do
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

    describe 'by expiration status' do
      let!(:old_event) { Fabricate(:event, name: 'old_event', original_starts_at: 2.hours.ago, original_ends_at: 1.hour.ago) }
      let!(:future_event) { Fabricate(:event, name: 'future_event', original_starts_at: 1.hour.from_now, original_ends_at: 2.hours.from_now) }
      let!(:current_event) { Fabricate(:event, name: 'current_event', original_starts_at: 5.minutes.ago, original_ends_at: 5.minutes.from_now) }
      let!(:older_event) { Fabricate(:event, name: 'older_event', original_starts_at: 4.hours.ago, original_ends_at: 3.hour.ago) }

      it 'returns correct events' do
        expect(subject.search(current_user, { expired: false })).to eq([current_event, future_event])
        expect(subject.search(current_user, { expired: true })).to eq([older_event, old_event])
      end

      context 'when a past event has been edited to be in the future' do
        let!(:event_date) { Fabricate(:event_date, event: future_event, starts_at: 2.hours.ago, ends_at: 1.hour.ago, finished_at: 1.hour.ago) }

        it 'returns correct events' do
          expect(subject.search(current_user, { expired: false })).to eq([current_event, future_event])
          expect(subject.search(current_user, { expired: true })).to eq([older_event, old_event])
        end
      end

      context 'when a future event has been edited to be in the past' do
        let!(:event_date) { Fabricate(:event_date, event: old_event, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now, finished_at: 1.hour.ago) }

        it 'returns correct events' do
          expect(subject.search(current_user, { expired: false })).to eq([current_event, future_event])
          expect(subject.search(current_user, { expired: true })).to eq([older_event, old_event])
        end
      end
    end
  end
end
