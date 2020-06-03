TIMEZONES_DEFINITIONS = 'https://raw.githubusercontent.com/moment/moment-timezone/develop/data/meta/latest.json'

task 'javascript:update_constants' => :environment do
  require 'holidays'
  holiday_regions = Holidays.available_regions.map(&:to_s) - ["ecbtarget", "federalreserve", "federalreservebanks", "fedex", "nerc", "unitednations", "ups"]

  time_zone_to_region = {}
  data = JSON.parse(URI.open(TIMEZONES_DEFINITIONS).read)
  data['zones'].each do |timezone, timezone_data|
    country_code = timezone_data['countries'].first.downcase
    next if !holiday_regions.include?(country_code)
    time_zone_to_region[timezone] = country_code
  end

  write_template("../../../plugins/discourse-calendar/assets/javascripts/lib/regions.js.es6", <<~JS)
    export const HOLIDAY_REGIONS = #{holiday_regions.to_json};

    export const TIME_ZONE_TO_REGION = #{time_zone_to_region.to_json};
  JS
end
