# frozen_string_literal: true

module Jobs
  class ::DiscourseCalendar::MonitorEventDates < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      DiscoursePostEvent::EventDate.pending.find_each do |event_date|
        send_reminder(event_date)
        trigger_events(event_date)
        finish(event_date)
      end
    end

    def send_reminder(event_date)
      due_reminders(event_date).each do |reminder|
        ::Jobs.enqueue(:discourse_post_event_send_reminder, event_id: event_date.event.id, reminder: reminder[:description])
        event_date.update!(reminder_counter: event_date.reminder_counter + 1)
      end
    end

    def trigger_events(event_date)
      if event_date.starts_at - 1.hour <= Time.current && event_date.event_will_start_sent_at.blank?
        event_date.update!(event_will_start_sent_at: DateTime.now)
        DiscourseEvent.trigger(:discourse_post_event_event_will_start, event_date.event)
      end

      if event_date.started? && event_date.event_started_sent_at.blank?
        event_date.update!(event_started_sent_at: DateTime.now)
        DiscourseEvent.trigger(:discourse_post_event_event_started, event_date.event)
      end
    end

    def finish(event_date)
      return if !event_date.ended?
      event_date.update!(finished_at: Time.current)

      DiscourseEvent.trigger(:discourse_post_event_event_ended, event_date.event)
      MessageBus.publish("/topic/#{event_date.event.post.topic_id}", reload_topic: true, refresh_stream: true)

      return if event_date.event.recurrence.blank?
      event_date.event.set_next_date
    end

    def due_reminders(event_date)
      return [] if event_date.event.reminders.blank?
      event_date.event.reminders.split(",").map do |reminder|
        value, unit = reminder.split('.')
        date = event_date.starts_at - value.to_i.send(unit)
        { description: reminder, date: date }
      end.select { |reminder| reminder[:date] <= Time.current }.sort_by { |reminder| reminder[:date] }.drop(event_date.reminder_counter)
    end
  end
end
