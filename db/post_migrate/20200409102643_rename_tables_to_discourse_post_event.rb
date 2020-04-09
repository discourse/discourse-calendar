# frozen_string_literal: true

class RenameTablesToDiscoursePostEvent < ActiveRecord::Migration[6.0]
  def up
    rename_table :discourse_calendar_post_events, :discourse_post_event_events
    rename_table :discourse_calendar_invitees, :discourse_post_event_invitees
  end

  def down
    rename_table :discourse_post_event_events, :discourse_calendar_post_events
    rename_table :discourse_post_event_invitees, :discourse_calendar_invitees
  end
end
