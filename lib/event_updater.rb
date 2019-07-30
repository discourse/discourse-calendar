# frozen_string_literal: true

module DiscourseCalendar
  class EventUpdater
    def self.update(post)
      op = post.topic.first_post
      dates = post.local_dates

      # if we don’t have any date it's not an event anymore
      if dates.empty?
        DiscourseCalendar::EventDestroyer.destroy(post)
        return
      end

      from = self.convert_to_date_time(dates[0])
      from = from.beginning_of_day unless dates[0]['time']

      if dates.count == 2
        to = self.convert_to_date_time(dates[1])
        to = to.end_of_day unless dates[1]['time']
      end

      html = post.cooked
      doc = Nokogiri::HTML::fragment(html)
      doc.css(".discourse-local-date").each(&:remove)
      html = (doc.try(:to_html) || html).sub(' → ', '')

      detail = [
        PrettyText.excerpt(html, 50, strip_links: true, text_entities: true),
        from.iso8601.to_s,
        to ? to.iso8601.to_s : nil,
        post.user.username_lower,
        dates[0]["recurring"].presence
      ]

      op.set_calendar_event(post.post_number, detail)
      op.save_custom_fields(true)
      op.publish_change_to_clients!(:calendar_change)
    end

    def self.convert_to_date_time(value)
      timezone = value["timezone"] || "UTC"

      if value['time']
        ActiveSupport::TimeZone[timezone].parse("#{value['date']} #{value['time']}")
      else
        ActiveSupport::TimeZone[timezone].parse(value['date'].to_s)
      end
    end
  end
end
