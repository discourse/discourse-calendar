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
      to = self.convert_to_date_time(dates[1]) if dates.count == 2
      adjust_to = !to || (to && !dates[1]['time'])

      if !to
        if dates[0]['time']
          to = from + 1.hour
          artificial_to = true
        end
      end

      if !SiteSetting.all_day_event_start_time.blank? && !SiteSetting.all_day_event_end_time.blank?
        from = from.change(change_for_setting(SiteSetting.all_day_event_start_time)) if !dates[0]['time']
        to = (to || from).change(change_for_setting(SiteSetting.all_day_event_end_time)) if adjust_to && !artificial_to
      end

      html = post.cooked
      doc = Nokogiri::HTML::fragment(html)
      doc.css(".discourse-local-date").each(&:remove)
      html = (doc.try(:to_html) || html).sub(' → ', '')

      detail = [
        PrettyText.excerpt(html, 1000, strip_links: true, text_entities: true, keep_emoji_images: true),
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
      datetime = value['date'].to_s
      datetime << " #{value['time']}" if value['time']
      ActiveSupport::TimeZone[timezone].parse(datetime)
    end

    def self.change_for_setting(setting)
      {
        hour: setting.split(':').first,
        min: setting.split(':').second
      }
    end
  end
end
