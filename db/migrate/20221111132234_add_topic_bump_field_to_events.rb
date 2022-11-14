# frozen_string_literal: true

class AddTopicBumpFieldToEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_post_event_events, :bump_topic, :string
  end
end
