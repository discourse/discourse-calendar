# frozen_string_literal: true

require "rrule"

class RRuleGenerator
  def self.generate(starts_at, tzid: nil, max_years: nil, recurrence_type: "every_week")
    tzid ||= "UTC"

    rrule = generate_hash(RRuleConfigurator.rule(recurrence_type, starts_at))
    rrule = set_mandatory_options(rrule, starts_at)

    ::RRule::Rule
      .new(stringify(rrule), dtstart: starts_at, exdate: [starts_at], tzid: tzid)
      .between(Time.current, Time.current + 14.months)
      .first(RRuleConfigurator.how_many_recurring_events(recurrence_type, max_years))
  end

  private

  def self.stringify(rrule)
    rrule.map { |k, v| "#{k}=#{v}" }.join(";")
  end

  def self.generate_hash(rrule)
    rrule
      .split(";")
      .each_with_object({}) do |rr, h|
        key, value = rr.split("=")
        h[key] = value
      end
  end

  def self.set_mandatory_options(rrule, time)
    rrule["BYHOUR"] = time.strftime("%H")
    rrule["BYMINUTE"] = time.strftime("%M")
    rrule["INTERVAL"] ||= 1
    rrule["WKST"] = "MO" # considers Monday as the first day of the week
    rrule
  end
end
