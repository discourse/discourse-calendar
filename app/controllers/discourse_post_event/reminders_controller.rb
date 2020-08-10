# frozen_string_literal: true

module DiscoursePostEvent
  class RemindersController < DiscoursePostEventController
    def destroy
      event = Event.find_by(id: params[:post_id])
      reminder = event.reminders.find_by(id: params[:id])
      guardian.ensure_can_act_on_discourse_post_event!(event)
      Jobs.cancel_scheduled_job(:discourse_post_event_send_reminder, reminder_id: reminder.id)
      reminder.destroy!
      render json: success_json
    end
  end
end
