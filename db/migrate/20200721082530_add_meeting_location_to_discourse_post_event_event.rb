class AddMeetingLocationToDiscoursePostEventEvent < ActiveRecord::Migration[6.0]
  def change
    add_column :discourse_post_event_events, :meetingLocation, :string
  end
end
