# frozen_string_literal: true

class DropIncorrectSchemaMigrations < ActiveRecord::Migration[6.0]
  def up
    execute <<-SQL
      DELETE FROM schema_migrations WHERE version = '20201303000001';
      DELETE FROM schema_migrations WHERE version = '20201303000002';
    SQL
  end
end
