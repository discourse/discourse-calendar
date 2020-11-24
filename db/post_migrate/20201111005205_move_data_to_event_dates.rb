# frozen_string_literal: true

class MoveDataToEventDates < ActiveRecord::Migration[6.0]
  def up
    rename_column :discourse_post_event_events, :starts_at, :original_starts_at
    rename_column :discourse_post_event_events, :ends_at, :original_ends_at

    return if DiscoursePostEvent::Event.count == 0

    DiscoursePostEvent::Event.find_each do |event|
      post = Post.find_by(id: event.id)
      next if !post
      extracted_event = DiscoursePostEvent::EventParser.extract_events(post).first
      next if !extracted_event

      finished_at = (event.original_ends_at < Time.current) && event.original_ends_at
      event_will_start_sent_at = event.original_starts_at - 1.hours
      event_started_sent_at = event.original_starts_at

      if finished_at
        execute "INSERT INTO discourse_calendar_post_event_dates(event_id, starts_at, ends_at, event_will_start_sent_at, event_started_sent_at, finished_at, reminder_counter, created_at, updated_at)
             VALUES (#{event.id}, '#{event.original_starts_at}', '#{event.original_ends_at}', '#{event_will_start_sent_at}', '#{event_started_sent_at}', '#{finished_at}', 0, now(), now())"
      else
        execute "INSERT INTO discourse_calendar_post_event_dates(event_id, starts_at, ends_at, reminder_counter, created_at, updated_at)
             VALUES (#{event.id}, '#{event.original_starts_at}', '#{event.original_ends_at}', 0, now(), now())"
      end

      event_date = DiscoursePostEvent::EventDate.order(:created_at).last
      event_date.update!(reminder_counter: DiscourseCalendar::MonitorEventDates.new.due_reminders(event_date).length)
      event_date.upsert_topic_custom_field
      event.update_columns(original_starts_at: extracted_event[:start], original_ends_at: extracted_event[:end])
    end

    Jobs.cancel_scheduled_job(:discourse_post_event_send_reminder)
    Jobs.cancel_scheduled_job(:discourse_post_event_event_started)
    Jobs.cancel_scheduled_job(:discourse_post_event_event_will_start)
    Jobs.cancel_scheduled_job(:discourse_post_event_event_ended)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
