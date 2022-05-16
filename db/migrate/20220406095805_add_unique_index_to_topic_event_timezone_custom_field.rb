# frozen_string_literal: true

class AddUniqueIndexToTopicEventTimezoneCustomField < ActiveRecord::Migration[6.1]
  def up
    add_index :topic_custom_fields,
      %i[name topic_id],
      name: :idx_topic_custom_fields_topic_post_event_timezone,
      unique: true,
      where: "name = 'TopicEventTimezone'"
  end
end

