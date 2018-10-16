module DiscourseCalendar
  class EventUpdater
    def self.update(post)
      op = post.topic.first_post
      dates = post.local_dates

      # if we don’t have any date it's not an event anymore
      if dates.empty?
        DiscourseCalendar::EventDestroyer.destroy(op, post.post_number.to_s)
        op.publish_change_to_clients!(:calendar_change)
        return
      end

      from = toDateTime(dates[0])
      from = from.beginning_of_day unless dates[0]['time']

      if dates.count == 2
        to = toDateTime(dates[1])
        to = to.end_of_day unless dates[1]['time']
      end

      html = post.cooked
      doc = Nokogiri::HTML::fragment(html)
      doc.css(".discourse-local-date").each { |span| span.remove }
      html = doc.try(:to_html) || html

      detail = []
      detail[DiscourseCalendar::MESSAGE_INDEX] = PrettyText.excerpt(html, 30, strip_links: true, text_entities: true).tr("\n", " ")
      detail[DiscourseCalendar::USERNAME_INDEX] = post.user.username_lower
      detail[DiscourseCalendar::FROM_INDEX] = from.iso8601.to_s
      detail[DiscourseCalendar::TO_INDEX] = to.iso8601.to_s if to

      op.set_calendar_detail(post.post_number, detail)
      op.save_custom_fields(true)
      op.publish_change_to_clients!(:calendar_change)
    end

    def self.toDateTime(value)
      timezone = value["timezone"] || "UTC"

      if value['time']
        ActiveSupport::TimeZone[timezone].parse("#{value['date']} #{value['time']}")
      else
        ActiveSupport::TimeZone[timezone].parse(value['date'].to_s)
      end
    end
  end
end
