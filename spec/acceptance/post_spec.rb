# frozen_string_literal: true

require "rails_helper"
require_relative '../fabricators/event_fabricator'

describe Post do
  Event ||= DiscoursePostEvent::Event

  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:post1) { Fabricate(:post, topic: topic) }
  fab!(:post_event) { Fabricate(:event, post: post1) }

  before do
    freeze_time
    SiteSetting.queue_jobs = false
    SiteSetting.discourse_post_event_enabled = true
  end

  context 'when a post is updated' do
    context 'when the post has a valid event' do
      context 'context the event markup is removed' do
        it 'destroys the associated event' do
          start = Time.now.utc.iso8601(3)

          post = PostCreator.create!(
            user,
            title: 'Sell a boat party',
            raw: "[wrap=event start=#{start}]\n[/wrap]",
          )

          expect(post.event.persisted?).to eq(true)

          revisor = PostRevisor.new(post, post.topic)
          revisor.revise!(user, raw: 'The event is over. Come back another day.')

          expect(post.reload.event).to be(nil)
        end
      end
    end
  end

  context 'when a post is created' do
    context 'when the post contains one valid event' do
      it 'creates the post event' do
        start = Time.now.utc.iso8601(3)

        post = PostCreator.create!(
          user,
          title: 'Sell a boat party',
          raw: "[wrap=event start=#{start}]\n[/wrap]",
        )

        expect(post.persisted?).to eq(true)
        expect(post.event.persisted?).to eq(true)
        expect(post.event.starts_at).to eq_time(Time.parse(start))
      end
    end

    context 'when the post contains one invalid event' do
      context 'when start is not provided or is invalid' do
        it 'raises an error' do
          expect {
            PostCreator.create!(
              user,
              title: 'Sell a boat party',
              raw: "[wrap=event end=\"1\"]\n[/wrap]",
            )
          }.to(
            raise_error(ActiveRecord::RecordNotSaved)
              .with_message(I18n.t("discourse_post_event.errors.models.event.start_must_be_present_and_a_valid_date"))
          )

          expect {
            PostCreator.create!(
              user,
              title: 'Sell a boat party',
              raw: "[wrap=event start=\"x\"]\n[/wrap]",
            )
          }.to(
            raise_error(ActiveRecord::RecordNotSaved)
              .with_message(I18n.t("discourse_post_event.errors.models.event.start_must_be_present_and_a_valid_date"))
          )
        end
      end

      context 'when end is provided and is invalid' do
        it 'raises an error' do
          expect {
            PostCreator.create!(
              user,
              title: 'Sell a boat party',
              raw: "[wrap=event start=\"#{Time.now.utc.iso8601(3)}\" end=\"d\"]\n[/wrap]",
            )
          }.to(
            raise_error(ActiveRecord::RecordNotSaved)
              .with_message(I18n.t("discourse_post_event.errors.models.event.end_must_be_a_valid_date"))
          )
        end
      end
    end

    context 'when the post contains multiple events' do
      it 'raises an error' do
        expect {
          PostCreator.create!(
            user,
            title: 'Sell a boat party',
            raw: "[wrap=event start=\"#{Time.now.utc.iso8601(3)}\"]\n[/wrap] foo [wrap=event start=\"#{Time.now.utc.iso8601(3)}\"]\n[/wrap]",
          )
        }.to(
          raise_error(ActiveRecord::RecordNotSaved)
            .with_message(I18n.t("discourse_post_event.errors.models.event.only_one_event"))
        )
      end
    end
  end

  context 'when a post with an event is destroyed' do
    it 'sets deleted_at on the post_event' do
      expect(post_event.deleted_at).to be_nil

      PostDestroyer.new(user, post_event.post).destroy
      post_event.reload

      expect(post_event.deleted_at).to eq_time(Time.now)
    end
  end

  context 'when a post with an event is recovered' do
    it 'nullifies deleted_at on the post_event' do
      PostDestroyer.new(user, post_event.post).destroy
      post_event.reload

      expect(post_event.deleted_at).to eq_time(Time.now)

      PostDestroyer.new(user, post_event.post).recover
      post_event.reload

      expect(post_event.deleted_at).to be_nil
    end
  end
end
