# frozen_string_literal: true

class AddLocalTimezone < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_post_event_events, :local_timezone, :string, limit: 255
  end
end
