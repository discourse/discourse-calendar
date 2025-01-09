# frozen_string_literal: true
module Jobs
  class ::DiscourseCalendar::MonitorEventDates < ::Jobs::Scheduled
    every 1.minute

    def execute(args)
      DiscoursePostEvent::EventDate.pending.find_each do |event_date|
        reminders = due_reminders(event_date)

        send_reminder(event_date, reminders)
        bump_topic(event_date, reminders)
        trigger_events(event_date)
        finish(event_date)
      end
    end

    def send_reminder(event_date, reminders)
      reminders.each do |reminder|
        next if reminder[:type] != "notification"

        ::Jobs.enqueue(
          :discourse_post_event_send_reminder,
          event_id: event_date.event.id,
          reminder: reminder[:description],
        )
        event_date.update!(reminder_counter: event_date.reminder_counter + 1)
      end
    end

    def bump_topic(event_date, reminders)
      reminders.each do |reminder|
        next if reminder[:type] != "bumpTopic"

        ::Jobs.enqueue(:discourse_post_event_bump_topic, event_id: event_date.event.id)
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
      MessageBus.publish(
        "/topic/#{event_date.event.post.topic_id}",
        reload_topic: true,
        refresh_stream: true,
      )

      return if event_date.event.recurrence.blank?
      event_date.event.set_next_date
    end

    def due_reminders(event_date)
      return [] if event_date.event.reminders.blank?
      event_date
        .event
        .reminders
        .split(",")
        .map do |reminder|
          unit, value, type = reminder.split(".").reverse
          next if !validate_reminder_unit(unit)

          if type.blank?
            reminder = "notification.#{value}.#{unit}"
            type = "notification"
          end

          date = event_date.starts_at - value.to_i.public_send(unit)
          { description: reminder, type: type, date: date }
        end
        .compact
        .select { |reminder| reminder[:date] <= Time.current }
        .sort_by { |reminder| reminder[:date] }
        .drop(event_date.reminder_counter)
    end

    private

    def validate_reminder_unit(input)
      ActiveSupport::Duration::PARTS.any? { |part| part.to_s == input }
    end
  end
end
