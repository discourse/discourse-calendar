# frozen_string_literal: true

class AddDateDeleteToPostEventDates < ActiveRecord::Migration[6.0]
  def up
    add_column :discourse_calendar_post_event_dates, :deleted_at, :datetime
    add_index :discourse_calendar_post_event_dates, :deleted_at
  end

  def down
    remove_column :discourse_calendar_post_event_dates, :deleted_at
  end
end
