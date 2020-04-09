# frozen_string_literal: true

class RenameFutureSchemaMigrations < ActiveRecord::Migration[5.2]
  def up
    execute "UPDATE schema_migrations SET version = '20200409102640' WHERE version = '20201303000001'"
    execute "UPDATE schema_migration_details SET version = '20200409102640' WHERE version = '20201303000001'"
    execute "UPDATE schema_migrations SET version = '20200409102641' WHERE version = '20201303000002'"
    execute "UPDATE schema_migration_details SET version = '20200409102641' WHERE version = '20201303000002'"
  end
end
