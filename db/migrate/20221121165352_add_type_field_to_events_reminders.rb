# frozen_string_literal: true

class AddTypeFieldToEventsReminders < ActiveRecord::Migration[7.0]
  def up
    DiscoursePostEvent::Event.where.not(reminders: nil).find_each do |event|
      refactored_reminders = []
      event.reminders.split(',') do |reminder|
        refactored_reminders.push(reminder.prepend("notification."))
      end
      event.reminders = refactored_reminders.join(',')
      event.save
    end
  end

  def down
    DiscoursePostEvent::Event.where.not(reminders: nil).find_each do |event|
      refactored_reminders = []
      event.reminders.split(',') do |reminder|
        next if !reminder.start_with?('notification')
        refactored_reminders.push(reminder.sub! 'notification.', '')
      end
      event.reminders = refactored_reminders.join(',')
      event.save
    end
  end
end
