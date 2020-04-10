# frozen_string_literal: true

module DiscoursePostEvent
  class EventsController < DiscoursePostEventController
    skip_before_action :check_xhr, only: [ :index ], if: :ics_request?

    def index
      @events = DiscoursePostEvent::EventFinder.search(current_user, filtered_events_params)

      respond_to do |format|
        format.ics {
          filename = "events-#{@events.map(&:id).join('-')}"
          response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}.#{request.format.symbol}\""
        }

        format.json do
          render json: ActiveModel::ArraySerializer.new(
            @events,
            each_serializer: EventSerializer,
            scope: guardian).as_json
        end
      end
    end

    def invite
      event = Event.find(params[:id])
      guardian.ensure_can_act_on_event!(event)
      invites = Array(params.permit(invites: [])[:invites])
      users = Invitee.extract_uniq_usernames(invites)

      users.each do |user|
        event.create_notification!(user, event.post)
      end

      render json: success_json
    end

    def show
      event = Event.find(params[:id])
      guardian.ensure_can_see!(event.post)
      serializer = EventSerializer.new(event, scope: guardian)
      render_json_dump(serializer)
    end

    def destroy
      event = Event.find(params[:id])
      guardian.ensure_can_act_on_event!(event)
      event.publish_update!
      event.destroy
      render json: success_json
    end

    def update
      DistributedMutex.synchronize("discourse-post-event[event-update]") do
        event = Event.find(params[:id])
        guardian.ensure_can_edit!(event.post)
        guardian.ensure_can_act_on_event!(event)
        event.enforce_utc!(event_params)

        case event_params[:status].to_i
        when Event.statuses[:private]
          raw_invitees = Array(event_params[:raw_invitees])
          event.update!(event_params.merge(raw_invitees: raw_invitees))
          event.enforce_raw_invitees!
        when Event.statuses[:public]
          event.update!(event_params.merge(raw_invitees: []))
        when Event.statuses[:standalone]
          event.update!(event_params.merge(raw_invitees: []))
          event.invitees.destroy_all
        end

        event.publish_update!
        serializer = EventSerializer.new(event, scope: guardian)
        render_json_dump(serializer)
      end
    end

    def create
      event = Event.new(event_params)
      guardian.ensure_can_edit!(event.post)
      guardian.ensure_can_create_event!(event)
      event.enforce_utc!(event_params)

      case event_params[:status].to_i
      when Event.statuses[:private]
        raw_invitees = Array(event_params[:raw_invitees])
        event.update!(raw_invitees: raw_invitees)
        event.fill_invitees!
        event.notify_invitees!
      when Event.statuses[:public], Event.statuses[:standalone]
        event.update!(event_params.merge(raw_invitees: []))
      end

      event.publish_update!
      serializer = EventSerializer.new(event, scope: guardian)
      render_json_dump(serializer)
    end

    private

    def event_params
      params
        .require(:event)
        .permit(
          :id,
          :name,
          :starts_at,
          :ends_at,
          :status,
          raw_invitees: []
        )
    end

    def ics_request?
      request.format.symbol == :ics
    end

    def filtered_events_params
      params.permit(:post_id)
    end
  end
end
