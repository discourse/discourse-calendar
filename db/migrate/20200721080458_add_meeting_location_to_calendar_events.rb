class AddMeetingLocationToCalendarEvents < ActiveRecord::Migration[6.0]
  def change
    add_column :calendar_events, :meetingLocation, :string
  end
end
