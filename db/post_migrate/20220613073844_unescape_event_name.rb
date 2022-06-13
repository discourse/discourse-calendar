# frozen_string_literal: true

class UnescapeEventName < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    # event notifications
    start = 1
    limit = DB.query_single("SELECT MAX(id) FROM notifications WHERE notification_type IN (27, 28)").first.to_i

    notifications_query = <<~SQL
      SELECT id, data
      FROM notifications
      WHERE
        id >= :start AND
        notification_type IN (27, 28) AND
        data::json ->> 'topic_title' LIKE '%&%'
      ORDER BY id ASC
      LIMIT 1000
    SQL
    while true
      if start > limit
        break
      end
      max_seen = -1
      DB.query(notifications_query, start: start).each do |record|
        id = record.id
        if id > max_seen
          max_seen = id
        end
        data = JSON.parse(record.data)
        unescaped = CGI.unescapeHTML(data["topic_title"])
        next if unescaped == data["topic_title"]
        data["topic_title"] = unescaped
        DB.exec(<<~SQL, data: data.to_json, id: id)
          UPDATE notifications SET data = :data WHERE id = :id
        SQL
      end
      start += 1000
      if max_seen > start
        start = max_seen + 1
      end
    end

    # event names
    events_query = <<~SQL
      SELECT id, name
      FROM discourse_post_event_events
      WHERE name LIKE '%&%'
      ORDER BY id ASC
    SQL

    DB.query(events_query).each do |event|
      unescaped_name = CGI.unescapeHTML(event.name)
      next if unescaped_name == event.name
      DB.exec(<<~SQL, unescaped_name: unescaped_name, id: event.id)
        UPDATE discourse_post_event_events SET name = :unescaped_name WHERE id = :id
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
