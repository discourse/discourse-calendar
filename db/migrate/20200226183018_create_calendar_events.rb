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

    # Rebuild calendar events
    calendar_topic_ids = Post
      .select(:topic_id)
      .joins('JOIN post_custom_fields ON posts.id = post_custom_fields.post_id')
      .where({ post_custom_fields: { name: 'calendar-details' }})
    Post.where(topic_id: calendar_topic_ids).each { |post| CalendarEvent.update(post) }
    PostCustomField.where(name: 'calendar-details').delete_all
  end
end
