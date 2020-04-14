# frozen_string_literal: true

module DiscoursePostEvent
  class InviteesController < DiscoursePostEventController
    def index
      event = Event.find(params['event-id'])

      event_invitees = event.invitees

      if params[:filter]
        event_invitees = event_invitees
          .joins(:user)
          .where("LOWER(users.username) LIKE :filter", filter: "%#{params[:filter].downcase}%")
      end

      if event.is_expired?
        event_invitees = event_invitees.where(status: Invitee.statuses[:going])
      end

      render json: ActiveModel::ArraySerializer.new(event_invitees.limit(10), each_serializer: InviteeSerializer).as_json
    end

    def update
      invitee = Invitee.find(params[:id])
      guardian.ensure_can_act_on_invitee!(invitee)
      status = Invitee.statuses[invitee_params[:status].to_sym]
      invitee.update_attendance(status: status)
      invitee.event.publish_update!
      render json: InviteeSerializer.new(invitee)
    end

    def create
      status = Invitee.statuses[invitee_params[:status].to_sym]
      event = Event.find(invitee_params[:post_id])
      guardian.ensure_can_act_on_discourse_post_event!(event)
      invitee = Invitee.create!(
        status: status,
        post_id: invitee_params[:post_id],
        user_id: current_user.id,
      )
      invitee.event.publish_update!
      render json: InviteeSerializer.new(invitee)
    end

    private

    def invitee_params
      params.require(:invitee).permit(:status, :post_id)
    end
  end
end
