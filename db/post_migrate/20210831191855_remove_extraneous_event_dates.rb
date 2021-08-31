# frozen_string_literal: true

class RemoveExtraneousEventDates < ActiveRecord::Migration[6.1]
  def up
    DB.exec <<~SQL
      DELETE FROM discourse_calendar_post_event_dates
      WHERE id NOT IN (
        SELECT MAX(dcped.id) FROM discourse_calendar_post_event_dates dcped
        LEFT JOIN discourse_post_event_events dpee ON dpee.id = dcped.event_id
        GROUP BY dcped.event_id
      ) AND id NOT IN (
        SELECT dcped.id FROM discourse_calendar_post_event_dates dcped
        LEFT JOIN discourse_post_event_events dpee ON dpee.id = dcped.event_id
        WHERE dpee.recurrence IS NOT NULL
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
