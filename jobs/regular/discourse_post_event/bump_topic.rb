# frozen_string_literal: true

module Jobs
  class DiscoursePostEventBumpTopic < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      raise Discourse::InvalidParameters.new(:event_id) if args[:event_id].blank?

      event = DiscoursePostEvent::Event.includes(post: %i[topic user]).find_by(id: args[:event_id])
      return unless event&.post&.topic && event.post.user

      if Guardian.new(event.post.user).can_create_post_on_topic?(event.post.topic)
        event.post.topic.add_small_action(Discourse.system_user, "autobumped", nil, bump: true)
      end
    end
  end
end
