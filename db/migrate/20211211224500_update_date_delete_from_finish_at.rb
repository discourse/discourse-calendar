# frozen_string_literal: true

class UpdateDateDeleteFromFinishAt < ActiveRecord::Migration[6.0]
  def up
    execute "update discourse_calendar_post_event_dates SET deleted_at = now() WHERE finished_at is not NULL;
UPDATE discourse_calendar_post_event_dates SET deleted_at = NULL
FROM  (
	SELECT DISTINCT ON (event_id)
		   id
	FROM  discourse_calendar_post_event_dates
	where finished_at is not null
	ORDER  BY event_id, updated_at DESC
) AS sq
WHERE  discourse_calendar_post_event_dates.id=sq.id;"
  end
end
