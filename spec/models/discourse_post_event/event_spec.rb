# frozen_string_literal: true

require 'rails_helper'

describe DiscoursePostEvent::Event do
  Event ||= DiscoursePostEvent::Event
  Invitee ||= DiscoursePostEvent::Invitee
  StartsAtField ||= DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT
  EndsAtField ||= DiscoursePostEvent::TOPIC_POST_EVENT_ENDS_AT

  before do
    freeze_time DateTime.parse('2020-04-24 14:10')
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  describe 'topic custom fields callback' do
    let(:user) { Fabricate(:user, admin: true) }
    let(:topic) { Fabricate(:topic, user: user) }
    let!(:first_post) { Fabricate(:post, topic: topic) }
    let(:second_post) { Fabricate(:post, topic: topic) }
    let!(:starts_at) { '2020-04-24 14:15:00' }
    let!(:ends_at) { '2020-04-24 16:15:00' }
    let!(:alt_starts_at) { '2020-04-24 14:14:25' }
    let!(:alt_ends_at) { '2020-04-24 19:15:25' }

    describe '#after_commit[:create, :update]' do
      context 'when a post event has been created' do
        context 'when the associated post is the OP' do
          it 'sets the topic custom field and creates event date' do
            expect(first_post.is_first_post?).to be(true)
            expect(first_post.topic.custom_fields).to be_blank

            expect {
              Event.create!(id: first_post.id, original_starts_at: starts_at, original_ends_at: ends_at)
            }.to change { DiscoursePostEvent::EventDate.count }
            first_post.topic.reload

            expect(first_post.topic.custom_fields[StartsAtField]).to eq(starts_at)
            expect(first_post.topic.custom_fields[EndsAtField]).to eq(ends_at)
            expect(DiscoursePostEvent::EventDate.last.starts_at).to eq_time(DateTime.parse(starts_at))
            expect(DiscoursePostEvent::EventDate.last.ends_at).to eq_time(DateTime.parse(ends_at))
          end
        end

        context 'when the associated post is not the OP' do
          it 'doesn’t set the topic custom field but still creates event date' do
            expect(second_post.is_first_post?).to be(false)
            expect(second_post.topic.custom_fields).to be_blank

            expect {
              Event.create!(id: second_post.id, original_starts_at: starts_at)
            }.to change { DiscoursePostEvent::EventDate.count }
            second_post.topic.reload

            expect(second_post.topic.custom_fields).to be_blank
          end
        end
      end

      context 'when a post event has been updated' do
        context 'when the associated post is the OP' do
          let!(:post_event) { Fabricate(:event, post: first_post, original_starts_at: starts_at,  original_ends_at: ends_at) }

          it 'sets the topic custom field' do
            first_post.topic.reload

            expect(first_post.is_first_post?).to be(true)
            expect(first_post.topic.custom_fields[StartsAtField]).to eq(starts_at)
            expect(first_post.topic.custom_fields[EndsAtField]).to eq(ends_at)

            first_event_date = post_event.event_dates.last
            expect(first_event_date.starts_at).to eq_time(DateTime.parse(starts_at))
            expect(first_event_date.finished_at).to be nil

            post_event.update_with_params!(original_starts_at: alt_starts_at, original_ends_at: alt_ends_at)
            first_post.topic.reload
            first_event_date.reload

            second_event_date = post_event.event_dates.last

            expect(first_post.topic.custom_fields[StartsAtField]).to eq(alt_starts_at)
            expect(first_post.topic.custom_fields[EndsAtField]).to eq(alt_ends_at)

            expect(first_event_date.finished_at).not_to be nil
            expect(second_event_date.starts_at).to eq_time(DateTime.parse(alt_starts_at))

            second_event_date.update_columns(finished_at: Time.current)
            expect(post_event.starts_at).to eq_time(DateTime.parse(alt_starts_at))
            expect(post_event.ends_at).to eq_time(DateTime.parse(alt_ends_at))
          end
        end

        context 'when the associated post is not the OP' do
          let(:post_event) { Fabricate(:event, post: second_post, original_starts_at: starts_at) }

          it 'doesn’t set the topic custom field' do
            expect(second_post.is_first_post?).to be(false)
            expect(second_post.topic.custom_fields[StartsAtField]).to be_blank

            post_event.update_with_params!(original_starts_at: alt_starts_at)
            second_post.topic.reload

            expect(second_post.topic.custom_fields[StartsAtField]).to be_blank

            second_event_date = post_event.event_dates.last
            expect(second_event_date.starts_at).to eq_time(DateTime.parse(alt_starts_at))
          end
        end
      end
    end

    describe '#after_commit[:destroy]' do
      context 'when a post event has been destroyed' do
        context 'when the associated post is the OP' do
          let!(:post_event) { Fabricate(:event, post: first_post, original_starts_at: starts_at, original_ends_at: ends_at) }

          it 'sets the topic custom field' do
            first_post.topic.reload

            expect(first_post.is_first_post?).to be(true)
            expect(first_post.topic.custom_fields[StartsAtField]).to eq(starts_at)
            expect(first_post.topic.custom_fields[EndsAtField]).to eq(ends_at)

            post_event.destroy!
            first_post.topic.reload

            expect(first_post.topic.custom_fields[StartsAtField]).to be_blank
            expect(first_post.topic.custom_fields[EndsAtField]).to be_blank
          end
        end

        context 'when the associated post is not the OP' do
          let!(:first_post_event) { Fabricate(:event, post: first_post, original_starts_at: starts_at, original_ends_at: ends_at) }
          let!(:second_post_event) { Fabricate(:event, post: second_post, original_starts_at: starts_at, original_ends_at: ends_at) }

          it 'doesn’t change the topic custom field' do
            second_post.topic.reload

            expect(first_post.is_first_post?).to be(true)
            expect(second_post.topic.custom_fields[StartsAtField]).to eq(starts_at)
            expect(second_post.topic.custom_fields[EndsAtField]).to eq(ends_at)
            expect(second_post.is_first_post?).to be(false)

            second_post_event.destroy!
            second_post.topic.reload

            expect(second_post.topic.custom_fields[StartsAtField]).to eq(starts_at)
            expect(second_post.topic.custom_fields[EndsAtField]).to eq(ends_at)
          end
        end
      end
    end
  end

  describe '#ongoing?' do
    let(:user) { Fabricate(:user, admin: true) }
    let(:topic) { Fabricate(:topic, user: user) }
    let!(:first_post) { Fabricate(:post, topic: topic) }

    context 'with ends_at' do
      context 'with starts_at < current date' do
        context 'with ends_at < current date' do
          it 'is ongoing' do
            post_event = Event.create!(
              original_starts_at: 2.hours.ago,
              original_ends_at: 1.hours.ago,
              post: first_post
            )

            expect(post_event.ongoing?).to be(false)
          end
        end

        context 'with ends_at > current date' do
          it 'is not ongoing' do
            post_event = Event.create!(
              original_starts_at: 2.hours.ago,
              original_ends_at: 3.hours.from_now,
              post: first_post
            )

            expect(post_event.ongoing?).to be(true)
          end
        end
      end

      context 'when starts_at > current date' do
        context 'when ends_at > current date' do
          it 'is not ongoing' do
            post_event = Event.create!(
              original_starts_at: 1.hour.from_now,
              original_ends_at: 2.hours.from_now,
              post: first_post
            )

            expect(post_event.ongoing?).to be(false)
          end
        end
      end
    end

    context 'without ends_at date' do
      context 'when starts_at < current date' do
        it 'is not ongoing' do
          post_event = Event.create!(
            original_starts_at: 2.hours.ago,
            post: first_post
          )

          expect(post_event.ongoing?).to be(false)
        end
      end

      context 'when starts_at == current date' do
        it 'is ongoing' do
          post_event = Event.create!(
            original_starts_at: Time.now,
            post: first_post
          )

          expect(post_event.ongoing?).to be(true)
        end
      end

      context 'when starts_at > current date' do
        it 'is ongoing' do
          post_event = Event.create!(
            original_starts_at: 1.hours.from_now,
            post: first_post
          )

          expect(post_event.ongoing?).to be(true)
        end
      end
    end
  end

  describe '#expired?' do
    let(:user) { Fabricate(:user, admin: true) }
    let(:topic) { Fabricate(:topic, user: user) }
    let!(:first_post) { Fabricate(:post, topic: topic) }

    context 'with ends_at' do
      context 'when starts_at < current date' do
        context 'when ends_at < current date' do
          it 'is expired' do
            post_event = Event.create!(
              original_starts_at: DateTime.parse('2020-04-22 14:05'),
              original_ends_at: DateTime.parse('2020-04-23 14:05'),
              post: first_post
            )

            expect(post_event.expired?).to be(true)
          end
        end

        context 'when ends_at > current date' do
          it 'is not expired' do
            post_event = Event.create!(
              original_starts_at: DateTime.parse('2020-04-24 14:15'),
              original_ends_at: DateTime.parse('2020-04-25 11:05'),
              post: first_post
            )

            expect(post_event.expired?).to be(false)
          end
        end
      end

      context 'when starts_at > current date' do
        it 'is not expired' do
          post_event = Event.create!(
            original_starts_at: DateTime.parse('2020-04-25 14:05'),
            original_ends_at: DateTime.parse('2020-04-26 14:05'),
            post: first_post
          )

          expect(post_event.expired?).to be(false)
        end
      end
    end

    context 'without ends_at date' do
      context 'when starts_at < current date' do
        it 'is expired' do
          post_event = Event.create!(
            original_starts_at: DateTime.parse('2020-04-24 14:05'),
            post: first_post
          )

          expect(post_event.expired?).to be(false)
        end
      end

      context 'when starts_at == current date' do
        it 'is expired' do
          post_event = Event.create!(
            original_starts_at: DateTime.parse('2020-04-24 14:10'),
            post: first_post
          )

          expect(post_event.expired?).to be(false)
        end
      end

      context 'when starts_at > current date' do
        it 'is not expired' do
          post_event = Event.create!(
            original_starts_at: DateTime.parse('2020-04-24 14:15'),
            post: first_post
          )

          expect(post_event.expired?).to be(false)
        end
      end
    end
  end

  describe '#update_with_params!' do
    let!(:post_1) { Fabricate(:post) }
    let!(:user_1) { Fabricate(:user) }
    let(:group_1) {
      Fabricate(:group).tap do |g|
        g.add(user_1)
        g.save!
      end
    }

    before do
      freeze_time
    end

    context 'with a private event' do
      let!(:event_1) {
        Fabricate(:event, post: post_1, status: Event.statuses[:private], raw_invitees: [group_1.name])
      }

      before do
        freeze_time

        event_1.create_invitees([
          { user_id: user_1.id, status: 0 }
        ])
      end

      context 'when updating the name' do
        it 'doesn’t clear existing invitees' do
          expect(event_1.invitees.count).to eq(1)

          expect {
            event_1.update_with_params!(name: 'The event')
          }.not_to change {
            event_1.invitees.count
          }
        end
      end
    end
  end

  describe '#missing_users' do
    let!(:post_1) { Fabricate(:post) }
    let!(:user_1) { Fabricate(:user) }
    let!(:user_2) { Fabricate(:user) }
    let!(:user_3) { Fabricate(:user) }
    let!(:group_1) {
      Fabricate(:group).tap do |g|
        g.add(user_1)
        g.add(user_2)
        g.add(user_3)
        g.save!
      end
    }
    let!(:group_2) {
      Fabricate(:group).tap do |g|
        g.add(user_2)
        g.save!
      end
    }
    let!(:event_1) { Fabricate(:event, post: post_1, status: Event.statuses[:private], raw_invitees: [group_1.name, group_2.name]) }

    before do
      Invitee.create_attendance!(user_3.id, post_1.id, :going)
    end

    it 'doesn’t return already attending user' do
      expect(event_1.missing_users.pluck(:id)).to_not include(user_3.id)
    end

    it 'return users from groups with no duplicates' do
      expect(event_1.missing_users.pluck(:id)).to match_array([user_1.id, user_2.id])
    end
  end
end
