# frozen_string_literal: true

module DiscoursePostEvent
  class InviteesController < DiscoursePostEventController
    def index
      event = Event.find(params['event-id'])

      event_invitees = event.invitees

      if params[:filter]
        event_invitees = event_invitees
          .joins(:user)
          .where('LOWER(users.username) LIKE :filter', filter: "%#{params[:filter].downcase}%")
      end

      render json: ActiveModel::ArraySerializer.new(
        event_invitees
          .order([:status, :user_id])
          .limit(10),
        each_serializer: InviteeSerializer
      ).as_json
    end

    def update
      invitee = Invitee.find(params[:id])
      guardian.ensure_can_act_on_invitee!(invitee)
      invitee.update_attendance!(invitee_params[:status])
      render json: InviteeSerializer.new(invitee)
    end

    def create
      event = Event.find(invitee_params[:post_id])
      guardian.ensure_can_see!(event.post)

      invitee = Invitee.create_attendance!(
        current_user.id,
        invitee_params[:post_id],
        invitee_params[:status]
      )
      render json: InviteeSerializer.new(invitee)
    end

    private

    def invitee_params
      params.require(:invitee).permit(:status, :post_id)
    end
  end
end
