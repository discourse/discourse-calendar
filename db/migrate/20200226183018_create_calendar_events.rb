# frozen_string_literal: true

class CreateCalendarEvents < ActiveRecord::Migration[5.2]
  def change
    create_table :calendar_events do |t|
      t.integer :topic_id, null: false
      t.integer :post_id
      t.integer :post_number
      t.integer :user_id
      t.string :username
      t.string :description
      t.datetime :start_date, null: false
      t.datetime :end_date
      t.string :recurrence
      t.string :region
      t.timestamps

      t.index :topic_id
      t.index :post_id
      t.index :user_id
    end

    # TODO: Rebake posts
  end
end
