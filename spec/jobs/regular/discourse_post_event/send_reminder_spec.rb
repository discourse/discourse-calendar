# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../fabricators/event_fabricator'

describe Jobs::DiscoursePostEventSendReminder do
  let(:admin_1) { Fabricate(:user, admin: true) }
  let(:topic_1) { Fabricate(:topic, user: admin_1) }
  let(:going_user) { Fabricate(:user) }
  let(:visited_going_user) { Fabricate(:user) }
  let(:not_going_user) { Fabricate(:user) }
  let(:going_user_unread_notification) { Fabricate(:user) }
  let(:going_user_read_notification) { Fabricate(:user) }
  let(:post_1) { Fabricate(:post, topic: topic_1) }
  let(:reminders) { '-5.minutes' }
  let(:event_1) { Fabricate(:event, post: post_1, reminders: reminders) }

  # ensures we start from a known state
  def init_notifications
    [
      going_user,
      not_going_user,
      going_user_unread_notification,
      going_user_read_notification,
      visited_going_user
    ].each do |user|
      user.notifications.update_all(read: true)
    end

    going_user_unread_notification.notifications.create!(
      notification_type: Notification.types[:custom],
      topic_id: post_1.topic_id,
      post_number: 1,
      data: {}.to_json
    )
  end

  before do
    freeze_time DateTime.parse('2018-11-10 12:00')
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true

    DiscoursePostEvent::Invitee.create_attendance!(going_user.id, event_1.id, :going)
    DiscoursePostEvent::Invitee.create_attendance!(not_going_user.id, event_1.id, :not_going)
    DiscoursePostEvent::Invitee.create_attendance!(going_user_unread_notification.id, event_1.id, :going)
    DiscoursePostEvent::Invitee.create_attendance!(going_user_read_notification.id, event_1.id, :going)
    DiscoursePostEvent::Invitee.create_attendance!(visited_going_user.id, event_1.id, :going)
  end

  context '#execute' do
    context 'invalid params' do
      context 'no invitees given' do
        it 'raises an invalid parameters errors' do
          expect {
            subject.execute(event_id: 1)
          }.to raise_error(Discourse::InvalidParameters)

          expect {
            subject.execute(reminder: 'foo')
          }.to raise_error(Discourse::InvalidParameters)
        end
      end
    end

    context 'valid params' do
      context 'event has not started' do
        before do
          event_1.update!(starts_at: Time.now + 1.hour)
          init_notifications
        end

        it 'creates a new notification for going user' do
          expect(going_user.unread_notifications).to eq(0)

          expect {
            subject.execute(event_id: event_1.id, reminder: reminders)
          }.to change { going_user.reload.unread_notifications }.by(1)
        end

        it 'doesn’t create a new notification for not going user' do
          expect(not_going_user.unread_notifications).to eq(0)

          expect {
            subject.execute(event_id: event_1.id, reminder: reminders)
          }.to change { not_going_user.reload.unread_notifications }.by(0)
        end

        it 'doesn’t create a new notification if there’s already one' do
          expect(going_user_unread_notification.unread_notifications).to eq(1)

          expect {
            subject.execute(event_id: event_1.id, reminder: reminders)
          }.to change { going_user_unread_notification.reload.unread_notifications }.by(0)
        end
      end

      context 'event has started' do
        before do
          event_1.update!(starts_at: 4.minutes.ago)
          init_notifications

          TopicUser.change(going_user, event_1.post.topic, last_visited_at: 10.minutes.ago, last_read_post_number: 1)
          TopicUser.change(visited_going_user, event_1.post.topic, last_visited_at: 2.minutes.ago, last_read_post_number: 1)
        end

        it 'creates a new notification for going user' do
          expect(going_user.unread_notifications).to eq(0)

          expect {
            subject.execute(event_id: event_1.id, reminder: reminders)
          }.to change { going_user.reload.unread_notifications }.by(1)
        end

        it 'doesn’t create a new notification for not going user' do
          expect(not_going_user.unread_notifications).to eq(0)

          expect {
            subject.execute(event_id: event_1.id, reminder: reminders)
          }.to change { not_going_user.reload.unread_notifications }.by(0)
        end

        it 'doesn’t create a new notification if there’s already one' do
          expect(going_user_unread_notification.unread_notifications).to eq(1)

          expect {
            subject.execute(event_id: event_1.id, reminder: reminders)
          }.to change {
            going_user_unread_notification.reload.unread_notifications
          }.by(0)
        end

        it 'doesn’t create a new notification for visiting user' do
          expect(visited_going_user.unread_notifications).to eq(0)

          expect {
            subject.execute(event_id: event_1.id, reminder: reminders)
          }.to change {
            visited_going_user.reload.unread_notifications
          }.by(0)
        end
      end
    end
  end
end
