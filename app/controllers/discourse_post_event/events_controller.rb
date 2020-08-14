# frozen_string_literal: true

module DiscoursePostEvent
  class EventsController < DiscoursePostEventController
    skip_before_action :check_xhr, only: [ :index ], if: :ics_request?

    def index
      @events = DiscoursePostEvent::EventFinder.search(current_user, filtered_events_params)

      respond_to do |format|
        format.ics do
          filename = "events-#{@events.map(&:id).join('-')}"
          response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}.#{request.format.symbol}\""
        end

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
      guardian.ensure_can_act_on_discourse_post_event!(event)
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
      guardian.ensure_can_act_on_discourse_post_event!(event)
      event.publish_update!
      event.destroy
      render json: success_json
    end

    # update is only used for custom fields
    # everything else is managed by cooking the post
    def update
      DistributedMutex.synchronize("discourse-post-event[event-update]") do
        event_params[:custom_fields] = (event_params[:custom_fields] || {}).reject { |_, value| value.blank? }

        event = Event.find(params[:id])
        guardian.ensure_can_edit!(event.post)
        guardian.ensure_can_act_on_discourse_post_event!(event)
        event.update!(event_params)
        serializer = EventSerializer.new(event, scope: guardian)
        render_json_dump(serializer)
      end
    end

    def csv_bulk_invite
      require 'csv'

      event = Event.find(params[:id])
      guardian.ensure_can_edit!(event.post)
      guardian.ensure_can_create_discourse_post_event!

      file = params[:file] || (params[:files] || []).first
      raise Discourse::InvalidParameters.new(:file) if file.blank?

      hijack do
        begin
          invitees = []

          CSV.foreach(file.tempfile) do |row|
            if row[0].present?
              invitees << { identifier: row[0], attendance: row[1] || 'going' }
            end
          end

          if invitees.present?
            Jobs.enqueue(
              :discourse_post_event_bulk_invite,
              event_id: event.id,
              invitees: invitees,
              current_user_id: current_user.id
            )
            render json: success_json
          else
            render json: failed_json.merge(errors: [I18n.t('discourse_post_event.errors.bulk_invite.error')]), status: 422
          end
        rescue
          render json: failed_json.merge(errors: [I18n.t('discourse_post_event.errors.bulk_invite.error')]), status: 422
        end
      end
    end

    def bulk_invite
      event = Event.find(params[:id])
      guardian.ensure_can_edit!(event.post)
      guardian.ensure_can_create_discourse_post_event!

      invitees = Array(params[:invitees]).reject { |x| x.empty? }
      raise Discourse::InvalidParameters.new(:invitees) if invitees.blank?

      begin
        Jobs.enqueue(
          :discourse_post_event_bulk_invite,
          event_id: event.id,
          invitees: invitees.as_json,
          current_user_id: current_user.id
        )
        render json: success_json
      rescue
        render json: failed_json.merge(errors: [I18n.t('discourse_post_event.errors.bulk_invite.error')]), status: 422
      end
    end

    private

    def event_params
      allowed_custom_fields = SiteSetting.discourse_post_event_allowed_custom_fields.split('|')

      params
        .require(:event)
        .permit(custom_fields: allowed_custom_fields)
    end

    def ics_request?
      request.format.symbol == :ics
    end

    def filtered_events_params
      params.permit(:post_id)
    end
  end
end
