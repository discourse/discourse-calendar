# frozen_string_literal: true

require 'migration/table_dropper'

class RenameTablesToDiscoursePostEvent < ActiveRecord::Migration[6.0]
  def up
    unless table_exists?(:discourse_post_event_events)
      Migration::TableDropper.read_only_table(:discourse_calendar_post_events)

      execute <<~SQL
      CREATE TABLE discourse_post_event_events
      AS TABLE discourse_calendar_post_events
      WITH NO DATA;
      SQL

      execute <<~SQL
      INSERT INTO discourse_post_event_events
      SELECT *
      FROM discourse_calendar_post_events
      SQL
    end

    unless table_exists?(:discourse_post_event_invitees)
      Migration::TableDropper.read_only_table(:discourse_calendar_invitees)

      execute <<~SQL
      CREATE TABLE discourse_post_event_invitees
      AS TABLE discourse_calendar_invitees
      WITH NO DATA;
      SQL

      execute <<~SQL
      INSERT INTO discourse_post_event_invitees
      SELECT *
      FROM discourse_calendar_invitees
      SQL
    end
  end

  def down
    raise ActiveRecord::IrrelversibleMigration
  end
end
