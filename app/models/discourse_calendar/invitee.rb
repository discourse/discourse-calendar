# frozen_string_literal: true

module DiscourseCalendar
  class Invitee < ActiveRecord::Base
    self.table_name = 'discourse_calendar_invitees'

    belongs_to :post_event, foreign_key: :post_id
    belongs_to :user

    scope :with_status, ->(status) {
      where(status: Invitee.statuses[status])
    }

    def self.statuses
      @statuses ||= Enum.new(going: 0, interested: 1, not_going: 2)
    end

    def update_attendance(params)
      self.update!(params)
    end
  end
end
