# frozen_string_literal: true

require 'rails_helper'
require_relative '../fabricators/event_fabricator'

describe DiscoursePostEvent::Event do
  Event ||= DiscoursePostEvent::Event
  Field ||= DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT

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
    let!(:alt_starts_at) { '2020-04-25 14:15:25' }

    describe '#after_commit[:create, :update]' do
      context 'a post event has been created' do
        context 'the associated post is the OP' do
          it 'sets the topic custom field' do
            expect(first_post.is_first_post?).to be(true)
            expect(first_post.topic.custom_fields).to be_blank

            Event.create!(id: first_post.id, starts_at: starts_at)
            first_post.topic.reload

            expect(first_post.topic.custom_fields[Field]).to eq(starts_at)
          end
        end

        context 'the associated post is not the OP' do
          it 'doesn’t set the topic custom field' do
            expect(second_post.is_first_post?).to be(false)
            expect(second_post.topic.custom_fields).to be_blank

            Event.create!(id: second_post.id, starts_at: starts_at)
            second_post.topic.reload

            expect(second_post.topic.custom_fields).to be_blank
          end
        end
      end

      context 'a post event has been updated' do
        context 'the associated post is the OP' do
          let!(:post_event) { Fabricate(:event, post: first_post, starts_at: starts_at) }

          it 'sets the topic custom field' do
            expect(first_post.is_first_post?).to be(true)
            expect(first_post.topic.custom_fields[Field]).to eq(starts_at)

            post_event.update!(starts_at: alt_starts_at)
            first_post.topic.reload

            expect(first_post.topic.custom_fields[Field]).to eq(alt_starts_at)
          end
        end

        context 'the associated post is not the OP' do
          let(:post_event) { Fabricate(:event, post: second_post, starts_at: starts_at) }

          it 'doesn’t set the topic custom field' do
            expect(second_post.is_first_post?).to be(false)
            expect(second_post.topic.custom_fields[Field]).to be_blank

            post_event.update!(starts_at: alt_starts_at)
            second_post.topic.reload

            expect(second_post.topic.custom_fields[Field]).to be_blank
          end
        end
      end
    end

    describe '#after_commit[:destroy]' do
      context 'a post event has been destroyed' do
        context 'the associated post is the OP' do
          let!(:post_event) { Fabricate(:event, post: first_post, starts_at: starts_at) }

          it 'sets the topic custom field' do
            expect(first_post.is_first_post?).to be(true)
            expect(first_post.topic.custom_fields[Field]).to eq(starts_at)

            post_event.destroy!
            first_post.topic.reload

            expect(first_post.topic.custom_fields[Field]).to be_blank
          end
        end

        context 'the associated post is not the OP' do
          let!(:first_post_event) { Fabricate(:event, post: first_post, starts_at: starts_at) }
          let!(:second_post_event) { Fabricate(:event, post: second_post, starts_at: starts_at) }

          it 'doesn’t change the topic custom field' do
            expect(first_post.is_first_post?).to be(true)
            expect(second_post.topic.custom_fields[Field]).to eq(starts_at)
            expect(second_post.is_first_post?).to be(false)

            second_post_event.destroy!
            second_post.topic.reload

            expect(second_post.topic.custom_fields[Field]).to eq(starts_at)
          end
        end
      end
    end
  end

  describe '#is_expired?' do
    context 'has ends_at' do
      context '&& starts_at < current date' do
        context '&& ends_at < current date' do
          it 'is expired' do
            post_event = Event.new(
              starts_at: DateTime.parse('2020-04-22 14:05'),
              ends_at: DateTime.parse('2020-04-23 14:05'),
            )

            expect(post_event.is_expired?).to be(true)
          end
        end

        context '&& ends_at > current date' do
          it 'is not expired' do
            post_event = Event.new(
              starts_at: DateTime.parse('2020-04-24 14:15'),
              ends_at: DateTime.parse('2020-04-25 11:05'),
            )

            expect(post_event.is_expired?).to be(false)
          end
        end

        context '&& ends_at < current date' do
          it 'is expired' do
            post_event = Event.new(
              starts_at: DateTime.parse('2020-04-22 14:15'),
              ends_at: DateTime.parse('2020-04-23 11:05'),
            )

            expect(post_event.is_expired?).to be(true)
          end
        end
      end

      context '&& starts_at > current date' do
        it 'is not expired' do
          post_event = Event.new(
            starts_at: DateTime.parse('2020-04-25 14:05'),
            ends_at: DateTime.parse('2020-04-26 14:05'),
          )

          expect(post_event.is_expired?).to be(false)
        end
      end
    end

    context 'has not ends_at date' do
      context '&& starts_at < current date' do
        it 'is expired' do
          post_event = Event.new(
            starts_at: DateTime.parse('2020-04-24 14:05')
          )

          expect(post_event.is_expired?).to be(true)
        end
      end

      context '&& starts_at == current date' do
        it 'is expired' do
          post_event = Event.new(
            starts_at: DateTime.parse('2020-04-24 14:10')
          )

          expect(post_event.is_expired?).to be(false)
        end
      end

      context '&& starts_at > current date' do
        it 'is not expired' do
          post_event = Event.new(
            starts_at: DateTime.parse('2020-04-24 14:15')
          )

          expect(post_event.is_expired?).to be(false)
        end
      end
    end
  end
end
