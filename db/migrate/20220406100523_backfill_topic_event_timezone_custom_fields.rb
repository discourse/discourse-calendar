# frozen_string_literal: true

class BackfillTopicEventTimezoneCustomFields < ActiveRecord::Migration[6.1]
  def up
    DB.exec <<~SQL
      INSERT
        INTO topic_custom_fields (name, value, topic_id, created_at, updated_at)
      SELECT 'TopicEventTimezone'
           , timezone
           , topic_id
           , created_at
           , updated_at
        FROM discourse_post_event_events dpee
        JOIN posts ON posts.id = dpee.id
       WHERE LENGTH(COALESCE(timezone, '')) > 0
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    DB.exec <<~SQL
      DELETE
        FROM topic_custom_fields
       WHERE name = 'TopicEventTimezone'
    SQL
  end
end

