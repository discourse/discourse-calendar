# frozen_string_literal: true

module DiscourseCalendar
  class DiscourseCalendarController < ::ApplicationController
    before_action :ensure_discourse_calendar_enabled
    skip_before_action :check_xhr, only: [ :topic_calendar ], if: :ics_request?

    def topic_calendar

      @topic = Topic.find_by(id: params[:id])

      if @topic && guardian.can_see?(@topic)
        @events = CalendarEvent.where(topic_id: @topic.id).order(:start_date, :end_date)

        respond_to do |format|
          format.ics do
            filename = "topic-#{@topic.id}-calendar"
            response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}.#{request.format.symbol}\""

            render :topic_calendar
          end
        end
      else
        raise Discourse::NotFound
      end
    end

    def post_dates
      @post = Post.find_by(id: params[:id])

      if @post && guardian.can_see?(@post)
        @events = LocalDatesExtractor.new(@post).extract_events
        respond_to do |format|
          format.ics do
            filename = "post-#{@post.id}-dates"
            response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}.#{request.format.symbol}\""

            render :post_dates
          end
        end
      else
        raise Discourse::NotFound
      end
    end

    def topic_dates
      @topic = Topic.find_by(id: params[:id])

      if @topic && guardian.can_see?(@topic)
        @events = @topic.posts.map{|p| LocalDatesExtractor.new(p).extract_events}.flatten

        respond_to do |format|
          format.ics do
            filename = "topic-#{@topic.id}-dates"
            response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}.#{request.format.symbol}\""

            render :post_dates
          end
        end
      else
        raise Discourse::NotFound
      end
    end

    private

    def ensure_discourse_calendar_enabled
      if !SiteSetting.calendar_enabled
        raise Discourse::NotFound
      end
    end

    def ics_request?
      request.format.symbol == :ics
    end
  end
end
