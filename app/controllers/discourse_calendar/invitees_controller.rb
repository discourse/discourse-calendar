# frozen_string_literal: true

module DiscourseCalendar
  class InviteesController < ::ApplicationController
    before_action :ensure_logged_in

    before_action :ensure_post_event_enabled
    def ensure_post_event_enabled
      if !SiteSetting.post_event_enabled
        raise Discourse::NotFound
      end
    end

    def index
      post_event_invitees = PostEvent.find(params['post-event-id']).invitees

      if params[:filter]
        post_event_invitees = post_event_invitees
          .joins(:user)
          .where("LOWER(users.username) LIKE :filter", filter: "%#{params[:filter].downcase}%")
      end

      render json: ActiveModel::ArraySerializer.new(post_event_invitees.limit(10), each_serializer: InviteeSerializer).as_json
    end

    def update
      invitee = Invitee.find(params[:id])
      guardian.ensure_can_act_on_invitee!(invitee)
      status = Invitee.statuses[invitee_params[:status].to_sym]
      invitee.update_attendance(status: status)
      invitee.post_event.publish_update!
      render json: InviteeSerializer.new(invitee)
    end

    def create
      status = Invitee.statuses[invitee_params[:status].to_sym]
      post_event = PostEvent.find(invitee_params[:post_id])
      guardian.ensure_can_act_on_post_event!(post_event)
      invitee = Invitee.create!(
        status: status,
        post_id: invitee_params[:post_id],
        user_id: current_user.id,
      )
      invitee.post_event.publish_update!
      render json: InviteeSerializer.new(invitee)
    end

    private

    def invitee_params
      params.require(:invitee).permit(:status, :post_id)
    end
  end
end
