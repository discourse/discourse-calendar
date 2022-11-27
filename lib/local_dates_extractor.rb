# frozen_string_literal: true

class LocalDatesExtractor
  Event = Struct.new(:start_date, :end_date, :description, :post)

  def initialize(post)
    @post = post  
  end

  def extract_events
    
    events = []

    Loofah.fragment(@post.cooked).css('span.discourse-local-date').map{|d| d.parent}.uniq.map do |paragraph_with_date|
      next if paragraph_with_date.ancestors("aside").length > 0

      event = Event.new
      dates = paragraph_with_date.css('span.discourse-local-date')

      # detects date ranges
      if dates.count == 2 && paragraph_with_date.content.include?(' → ')
        to, from = dates.each do |cooked_date|
          date = {}
          cooked_date.attributes.values.each do |attribute|
            data_name = attribute.name&.gsub('data-', '')
            if data_name && %w[date time timezone recurring].include?(data_name)
              unless attribute.value == 'undefined'
                date[data_name] = CGI.escapeHTML(attribute.value || '')
              end
            end
          end
        end
        event.start_date = LocalDatesExtractor.convert_to_date_time(from)
        event.end_date = LocalDatesExtractor.convert_to_date_time(to)
      else #no ranges
        date = {}
        paragraph_with_date.css('span.discourse-local-date').attributes.values.each do |attribute|
          data_name = attribute.name&.gsub('data-', '')
          if data_name && %w[date time timezone recurring].include?(data_name)
            unless attribute.value == 'undefined'
              date[data_name] = CGI.escapeHTML(attribute.value || '')
            end
          end
        end

        event.start_date = LocalDatesExtractor.convert_to_date_time(date)
      end
      event.description = paragraph_with_date.children.reject{|c| c&.attributes.dig('class')&.value == 'discourse-local-date'}&.map{|c| c.text}&.join&.gsub(' → ', '')
      event.post = @post
      events << event
    end

    events
  end


  private

  def self.convert_to_date_time(value)
    return if value.blank?

    attrs = value.attributes

    datetime = attrs['data-date'].value
    datetime << " #{attrs['data-time'].value}" if attrs['time']
    timezone = attrs['data-timezone'].value || 'UTC'

    ActiveSupport::TimeZone[timezone].parse(datetime)
  end
end
