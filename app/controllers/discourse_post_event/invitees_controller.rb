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

      render json: ActiveModel::ArraySerializer.new(event_invitees.limit(10), each_serializer: InviteeSerializer).as_json
    end

    def update
      invitee = Invitee.upsert_attendance!(params[:id], invitee_params, guardian)
      render json: InviteeSerializer.new(invitee)
    end

    def create
      invitee = Invitee.upsert_attendance!(current_user.id, invitee_params, guardian)
      render json: InviteeSerializer.new(invitee)
    end

    private

    def invitee_params
      params.require(:invitee).permit(:status, :post_id)
    end
  end
end
