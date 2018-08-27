module Jobs
  class ::DiscourseSimpleCalendar::EnsuredExpiredEventDestruction < Jobs::Scheduled
    every 6.hours

    def execute(args)
      PostCustomField
        .joins(:post)
        .where("post_custom_fields.name = '#{::DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD}'")
        .find_each do |pcf|
          details = JSON.parse(pcf.value)

          details.each do |post_number, detail|
            to = detail[::DiscourseSimpleCalendar::TO_INDEX] ||
                 detail[::DiscourseSimpleCalendar::FROM_INDEX]

            to_time = Time.parse(to)
            to_time += 24.hours unless detail[::DiscourseSimpleCalendar::TO_INDEX] # Add 24 hours if no explicit 'to' time

            if (to_time + 1.hour) < Time.now.utc
              op = pcf.post
              topic = op.topic
              post = topic.posts.find_by(post_number: post_number)
              DiscourseSimpleCalendar::EventDestroyer.destroy(op, post_number.to_s)

              if post
                PostDestroyer.new(Discourse.system_user, post).destroy
              end
            end
          end
        end
    end
  end
end
