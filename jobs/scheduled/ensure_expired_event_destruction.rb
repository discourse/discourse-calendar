module Jobs
  class ::DiscourseSimpleCalendar::EnsuredExpiredEventDestruction < Jobs::Scheduled
    every 1.day

    def execute()
      PostCustomField.joins(:post).where("post_custom_fields.name = '#{::DiscourseSimpleCalendar::CALENDAR_DETAILS_CUSTOM_FIELD}'")
        .find_each do |pcf|
          details = JSON.parse(pcf.value)

          details.each do |post_number, detail|
            to = detail[::DiscourseSimpleCalendar::TO_INDEX] ||
                 detail[::DiscourseSimpleCalendar::FROM_INDEX]

            if (Time.parse(to) + 1.day) < Time.now.utc
              post = pcf.post
              op = post.topic.first_post

              Jobs.cancel_scheduled_job(:destroy_expired_event, post_id: post.id)

              DiscourseSimpleCalendar::EventDestroyer.destroy(op, post_number.to_s)
            end
          end
        end
    end
  end
end
