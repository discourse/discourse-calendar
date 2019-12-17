# frozen_string_literal: true

module Jobs
  class ::DiscourseCalendar::EnsuredExpiredEventDestruction < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      return unless SiteSetting.calendar_enabled

      delay = SiteSetting.delete_expired_event_posts_after

      return if delay < 0

      calendar_post_ids = PostCustomField
        .where(name: ::DiscourseCalendar::CALENDAR_CUSTOM_FIELD)
        .pluck(:post_id)

      calendar_topic_ids = Post
        .joins(:topic)
        .where(id: calendar_post_ids, post_number: 1)
        .where("NOT topics.closed AND NOT topics.archived")
        .pluck(:topic_id)

      PostCustomField
        .joins(post: :topic)
        .includes(post: :topic)
        .where("post_custom_fields.name = ?", ::DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD)
        .where("topics.id IN (?)", calendar_topic_ids)
        .find_each do |pcf|

        posts_with_dates = JSON.parse(pcf.value)
        post_numbers_with_dates = posts_with_dates.keys.map(&:to_i)
        posts_with_dates.each do |post_number, (_, from, to, _, recurring)|
          next if recurring

          to_time = to ? Time.parse(to) : Time.parse(from) + 24.hours
          next if (to_time + delay.hour) > Time.zone.now

          if post = pcf.post.topic.posts.find_by(post_number: post_number)
            post.post_replies.each do |post_reply|
              # we do not want to destroy any direct replies with dates
              # (they will get destroyed automatically when their time comes)
              reply_post = post_reply.reply
              next if post_numbers_with_dates.include?(reply_post.post_number)
              destroy_post(reply_post)
            end

            destroy_post(post)
          end
        end
      end
    end

    def destroy_post(post)
      PostDestroyer.new(Discourse.system_user, post).destroy
    end
  end
end
