# frozen_string_literal: true

require "rails_helper"
require_relative '../fabricators/event_fabricator'

module DiscoursePostEvent
  describe RemindersController do
    let(:admin_1) { Fabricate(:user, admin: true) }

    before do
      freeze_time
      Jobs.run_immediately!
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      sign_in(admin_1)
    end

    context 'destroying a reminder' do
      let!(:post_1) { create_post_with_event(admin_1) }

      before do
        post_1.reload
        post_1.event.reminders.create!(value: 15, unit: 'minutes')
      end

      context 'current user is allowed to destroy it' do
        it 'detroys the reminder' do
          reminders = post_1.event.reminders
          reminder = reminders.first

          expect(reminders.count).to eq(1)
          Jobs.expects(:cancel_scheduled_job).with(:discourse_post_event_send_reminder, reminder_id: reminder.id).once

          delete "/discourse-post-event/events/#{post_1.id}/reminders/#{reminder.id}.json"

          expect(response.status).to eq(200)
          expect(reminders.count).to eq(0)
        end
      end

      context 'current user is not allowed to destroy it' do
        let(:lurker) { Fabricate(:user) }

        before do
          sign_in(lurker)
        end

        it 'it doesn’t destroy the reminder' do
          reminders = post_1.event.reminders
          expect(reminders.count).to eq(1)
          delete "/discourse-post-event/events/#{post_1.id}/reminders/#{reminders.first.id}.json"
          expect(response.status).to eq(403)
          expect(reminders.count).to eq(1)
        end
      end
    end
  end
end
