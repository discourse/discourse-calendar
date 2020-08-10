# frozen_string_literal: true

module DiscoursePostEvent
  class Reminder < ActiveRecord::Base
    self.table_name = 'discourse_post_event_reminders'

    belongs_to :event, foreign_key: :post_id

    def self.means
      @means ||= Enum.new(notification: 0)
    end

    after_commit :refresh!, on: [:create, :update]
    def refresh!
      if transaction_include_any_action?([:update])
        Jobs.cancel_scheduled_job(:discourse_post_event_send_reminder, reminder_id: self.id)
      end

      enqueue_at = self.event.starts_at - self.value.send(self.unit)
      if enqueue_at > Time.now
        Jobs.enqueue_at(enqueue_at, :discourse_post_event_send_reminder, reminder_id: self.id)
      end
    end
  end
end
