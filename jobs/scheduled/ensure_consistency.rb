# frozen_string_literal: true

module Jobs
  class ::DiscourseCalendar::EnsureConsistency < ::Jobs::Scheduled
    every 12.hours

    PLUGIN_NAME ||= "calendar"

    def execute(args)
      return unless SiteSetting.calendar_enabled
      return unless topic_id = SiteSetting.holiday_calendar_topic_id
      return unless op = Post.find_by(topic_id: topic_id, post_number: 1)
      return unless op.calendar_details.present?

      posts = Post
        .where(topic_id: topic_id, post_number: op.calendar_details.keys)
        .where("raw NOT LIKE '%[date%'")

      posts.find_each do |post|
        DistributedMutex.synchronize("#{PLUGIN_NAME}-#{post.id}") do
          DiscourseCalendar::EventUpdater.update(post)
        end
      end
    end
  end
end
