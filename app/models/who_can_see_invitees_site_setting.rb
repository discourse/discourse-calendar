# frozen_string_literal: true

require "enum_site_setting"

class WhoCanSeeInviteesSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    @values ||= [
      {
        name: "discourse_calendar.who_can_see_invitees.only_who_can_act",
        value: "only_who_can_act",
      },
      {
        name: "discourse_calendar.who_can_see_invitees.all_logged_in_users",
        value: "all_logged_in_users",
      },
      {
        name: "discourse_calendar.who_can_see_invitees.event_creator_and_who_can_act",
        value: "event_creator_and_who_can_act",
      },
    ]
  end

  def self.translate_names?
    true
  end
end
