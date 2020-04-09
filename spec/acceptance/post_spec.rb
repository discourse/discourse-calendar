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
