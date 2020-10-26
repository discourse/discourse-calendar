# frozen_string_literal: true

require 'rrule'

class RRuleGenerator
  def self.generate(base_rrule, starts_at)
    rrule = generate_hash(base_rrule)
    rrule = set_mandatory_options(rrule, starts_at)

    ::RRule::Rule.new(stringify(rrule), dtstart: starts_at, exdate: [starts_at])
      .between(Time.current, Time.current + 2.months)
      .first
  end

  private

  def self.stringify(rrule)
    rrule.map { |k, v| "#{k}=#{v}" }.join(';')
  end

  def self.generate_hash(rrule)
    rrule.split(';').each_with_object({}) do |rr, h|
      key, value = rr.split('=')
      h[key] = value
    end
  end

  def self.set_mandatory_options(rrule, time)
    rrule['BYHOUR'] = time.strftime('%H')
    rrule['BYMINUTE'] = time.strftime('%M')
    rrule['INTERVAL'] = 1
    rrule['WKST'] = 'MO' # considers Monday as the first day of the week
    rrule
  end
end
