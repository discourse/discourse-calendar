# frozen_string_literal: true

module DiscourseCalendar
  class PostEventsController < ::ApplicationController
    before_action :ensure_logged_in

    before_action :ensure_post_event_enabled
    def ensure_post_event_enabled
      if !SiteSetting.post_event_enabled
        raise Discourse::NotFound
      end
    end

    def index
      # TODO: optimize this
      post_events_topics_ids = PostEvent
        .visible
        .where('starts_at > ?', Time.now)
        .joins(:post)
        .limit(100)
        .select('posts.topic_id')

      secured_topic_ids = Topic
        .visible
        .listable_topics
        .where(id: post_events_topics_ids)
        .secured(guardian)
        .select(:id)

      post_events = PostEvent
        .visible
        .joins(:post)
        .where('posts.topic_id' => secured_topic_ids)
        .where('starts_at > ?', Time.now)
        .limit(10)

      render json: ActiveModel::ArraySerializer.new(
        post_events,
        each_serializer: PostEventSerializer,
        scope: guardian).as_json
    end

    def invite
      post_event = PostEvent.find(params[:id])
      guardian.ensure_can_act_on_post_event!(post_event)
      invites = Array(params.permit(invites: [])[:invites])
      users = User.where(
        id: GroupUser.where(
          group_id: Group.where(name: invites).select(:id)
        ).select(:user_id)
      ).or(User.where(username: invites))

      users.each do |user|
        post_event.create_notification!(user, post_event.post)
      end

      render json: success_json
    end

    def show
      post_event = DiscourseCalendar::PostEvent.find(params[:id])
      guardian.ensure_can_see!(post_event.post)
      serializer = PostEventSerializer.new(post_event, scope: guardian)
      render_json_dump(serializer)
    end

    def destroy
      post_event = DiscourseCalendar::PostEvent.find(params[:id])
      guardian.ensure_can_act_on_post_event!(post_event)
      post_event.publish_update!
      post_event.destroy
      render json: success_json
    end

    def update
      DistributedMutex.synchronize("discourse-calendar[post-event-invitee-update]") do
        post_event = DiscourseCalendar::PostEvent.find(params[:id])
        guardian.ensure_can_edit!(post_event.post)
        guardian.ensure_can_act_on_post_event!(post_event)
        post_event.enforce_utc!(post_event_params)

        case post_event_params[:status].to_i
        when PostEvent.statuses[:private]
          raw_invitees = Array(post_event_params[:raw_invitees])
          post_event.update!(post_event_params.merge(raw_invitees: raw_invitees))
          post_event.enforce_raw_invitees!
        when PostEvent.statuses[:public]
          post_event.update!(post_event_params.merge(raw_invitees: []))
        when PostEvent.statuses[:standalone]
          post_event.update!(post_event_params.merge(raw_invitees: []))
          post_event.invitees.destroy_all
        end

        post_event.publish_update!
        serializer = PostEventSerializer.new(post_event, scope: guardian)
        render_json_dump(serializer)
      end
    end

    def create
      post_event = DiscourseCalendar::PostEvent.new(post_event_params)
      guardian.ensure_can_edit!(post_event.post)
      guardian.ensure_can_create_post_event!(post_event)
      post_event.enforce_utc!(post_event_params)

      case post_event_params[:status].to_i
      when PostEvent.statuses[:private]
        raw_invitees = Array(post_event_params[:raw_invitees])
        post_event.update!(raw_invitees: raw_invitees)
        post_event.fill_invitees!
        post_event.notify_invitees!
      when PostEvent.statuses[:public], PostEvent.statuses[:standalone]
        post_event.update!(post_event_params.merge(raw_invitees: []))
      end

      post_event.publish_update!
      serializer = PostEventSerializer.new(post_event, scope: guardian)
      render_json_dump(serializer)
    end

    private

    def post_event_params
      params
        .require(:post_event)
        .permit(
          :id,
          :name,
          :starts_at,
          :ends_at,
          :status,
          :display_invitees,
          raw_invitees: []
        )
    end
  end
end
