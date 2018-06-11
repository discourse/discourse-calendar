module Jobs
  class ::DiscourseSimpleCalendar::EnsuredExpiredEventDestruction < Jobs::Scheduled
    every 1.day

    def execute
      PostCustomField
        .joins(:post)
        .where("post_custom_fields.name = '#{::DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD}'")
        .find_each do |pcf|
          details = JSON.parse(pcf.value)

          details.each do |post_number, detail|
            to = detail[::DiscourseSimpleCalendar::TO_INDEX] ||
                 detail[::DiscourseSimpleCalendar::FROM_INDEX]

            if (Time.parse(to) + 1.day) < Time.now.utc
              op = pcf.post
              topic = op.topic
              post = topic.posts.find_by(post_number: post_number)
              DiscourseSimpleCalendar::EventDestroyer.destroy(op, post_number.to_s)
              PostDestroyer.new(Discourse.system_user, post).destroy
            end
          end
        end
    end
  end
end
