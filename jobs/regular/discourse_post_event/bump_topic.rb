# frozen_string_literal: true

module Jobs
  class DiscoursePostEventBumpTopic < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      raise Discourse::InvalidParameters.new(:topic_id) if args[:topic_id].blank?
      raise Discourse::InvalidParameters.new(:date) if args[:date].blank?

      topic = Topic.find_by(id: args[:topic_id].to_i)
      topic.set_or_create_timer("bump", args[:date])
    end
  end
end
