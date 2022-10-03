# frozen_string_literal: true
require 'rails_helper'

describe DiscourseCalendar::MonitorEventDates do
  fab!(:post_1) { Fabricate(:post) }
  fab!(:post_2) { Fabricate(:post) }
  fab!(:past_event) { Fabricate(:event, post: post_1, original_starts_at: 7.days.after, original_ends_at: 7.days.after + 1.hour, reminders: '15.minutes,1.hours') }
  let(:past_date) { past_event.event_dates.first }
  fab!(:future_event) { Fabricate(:event, post: post_2, original_starts_at: 14.days.after, original_ends_at: 14.days.after + 1.hour) }
  let(:future_date) { future_event.event_dates.first }

  describe '#send_reminder' do
    it 'lodge reminder jobs in correct times' do
      expect_not_enqueued_with(job: :discourse_post_event_send_reminder) do
        described_class.new.execute({})
      end

      freeze_time (7.days.after - 59.minutes)
      expect_enqueued_with(job: :discourse_post_event_send_reminder, args: { event_id: past_event.id, reminder: '1.hours' }) do
        described_class.new.execute({})
      end

      freeze_time (7.days.after - 14.minutes)
      expect_enqueued_with(job: :discourse_post_event_send_reminder, args: { event_id: past_event.id, reminder: '15.minutes' }) do
        described_class.new.execute({})
      end

      freeze_time 7.days.after
      expect_not_enqueued_with(job: :discourse_post_event_send_reminder) do
        described_class.new.execute({})
      end
    end
  end

  describe '#trigger_events' do
    it 'sends singe event 1 hours before and when due' do
      events = DiscourseEvent.track_events do
        described_class.new.execute({})
      end
      expect(events).not_to include(event_name: :discourse_post_event_event_will_start, params: [past_event])
      expect(events).not_to include(event_name: :discourse_post_event_event_started, params: [past_event])

      events = DiscourseEvent.track_events do
        described_class.new.execute({})
      end

      freeze_time (7.days.after - 59.minutes)
      events = DiscourseEvent.track_events do
        described_class.new.execute({})
      end
      expect(events).to include(event_name: :discourse_post_event_event_will_start, params: [past_event])
      expect(events).not_to include(event_name: :discourse_post_event_event_started, params: [past_event])

      freeze_time (7.days.after)
      events = DiscourseEvent.track_events do
        described_class.new.execute({})
      end
      expect(events).not_to include(event_name: :discourse_post_event_event_will_start, params: [past_event])
      expect(events).to include(event_name: :discourse_post_event_event_started, params: [past_event])

      events = DiscourseEvent.track_events do
        described_class.new.execute({})
      end
      expect(events).not_to include(event_name: :discourse_post_event_event_will_start, params: [past_event])
      expect(events).not_to include(event_name: :discourse_post_event_event_started, params: [past_event])
    end
  end

  describe '#finish' do
    it 'finishes past event' do
      described_class.new.execute({})
      expect(future_date.finished_at).to eq(nil)
      expect(past_date.finished_at).to eq(nil)

      freeze_time 8.days.after

      described_class.new.execute({})
      expect(future_date.finished_at).to eq(nil)
      expect(past_event.event_dates.pending.count).to eq(0)
      # expect(past_date.finished_at).not_to eq(nil)
    end

    it 'creates new date for recurrent events' do
      past_event.update!(recurrence: 'every_week')

      freeze_time 8.days.after

      events = DiscourseEvent.track_events do
        described_class.new.execute({})
      end
      expect(future_date.finished_at).to eq(nil)
      expect(past_event.event_dates.pending.count).to eq(1)
      expect(past_event.event_dates.pending.first.starts_at.to_s).to eq((past_date.starts_at + 7.days).to_s)
      expect(events).to include(event_name: :discourse_post_event_event_ended, params: [past_event])
    end
  end

  describe '#due_reminders' do
    fab!(:invalid_event) {
      Fabricate(
        :event,
        post: Fabricate(:post),
        original_starts_at: 7.days.after,
        original_ends_at: 7.days.after + 1.hour,
        reminders: "1.foo"
      )
    }

    fab!(:valid_event) {
      Fabricate(
        :event,
        post: Fabricate(:post),
        original_starts_at: 7.days.after,
        original_ends_at: 7.days.after + 1.hour,
        reminders: "1.minutes"
      )
    }

    it 'doesn’t list events with invalid reminders' do
      freeze_time (7.days.after - 1.minutes)
      event_dates_monitor = DiscourseCalendar::MonitorEventDates.new

      expect(event_dates_monitor.due_reminders(invalid_event.event_dates.first)).to be_blank
      expect(event_dates_monitor.due_reminders(valid_event.event_dates.first).length).to eq(1)
    end
  end
end
