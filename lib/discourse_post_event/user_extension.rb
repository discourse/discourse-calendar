# frozen_string_literal: true

module DiscoursePostEvent
  module UserExtension
    extend ActiveSupport::Concern

    prepended do
      has_many :event_invites,
               dependent: :destroy,
               class_name: "DiscoursePostEvent::Invitee",
               foreign_key: :id
    end
  end
end
