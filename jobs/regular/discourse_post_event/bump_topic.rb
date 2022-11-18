# frozen_string_literal: true

module Jobs
  class DiscoursePostEventBumpTopic < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      raise Discourse::InvalidParameters.new(:topic_id) if args[:topic_id].blank?
      raise Discourse::InvalidParameters.new(:date) if args[:date].blank?

      puts "run job"
      topic = Topic.find_by(id: args[:topic_id].to_i)
      event_user = User.find_by(id: topic.user_id)

      topic.set_or_create_timer(TopicTimer.types[:bump], args[:date], by_user: event_user)

    end
  end
end
