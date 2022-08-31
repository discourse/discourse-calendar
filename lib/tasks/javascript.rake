# frozen_string_literal: true

require "open-uri"

TIMEZONES_DEFINITIONS = 'https://raw.githubusercontent.com/moment/moment-timezone/develop/data/meta/latest.json'
UNUSED_REGIONS = ["ecbtarget", "federalreserve", "federalreservebanks", "fedex", "nerc", "unitednations", "ups", 'nyse']
HOLIDAYS_COUNTRY_OVERRIDES = { "gr" => "el" }

task 'javascript:update_constants' => :environment do
  require 'holidays' if !defined?(Holidays)

  holiday_regions = Holidays.available_regions.map(&:to_s) - UNUSED_REGIONS

  time_zone_to_region = {}
  data = JSON.parse(URI.parse(TIMEZONES_DEFINITIONS).open.read)
  data['zones'].sort.each do |timezone, timezone_data|
    country_code = timezone_data['countries'].first.downcase
    if HOLIDAYS_COUNTRY_OVERRIDES.include?(country_code)
      country_code = HOLIDAYS_COUNTRY_OVERRIDES[country_code]
    end

    next if !holiday_regions.include?(country_code)
    time_zone_to_region[timezone] = country_code
  end

  write_template("../../../plugins/discourse-calendar/assets/javascripts/lib/regions.js", 'update_constants', <<~JS)
    export const HOLIDAY_REGIONS = #{holiday_regions.to_json};

    export const TIME_ZONE_TO_REGION = #{time_zone_to_region.to_json};
  JS
end
