# encoding: utf-8
module Holidays
  # This file is generated by the Ruby Holidays gem.
  #
  # Definitions loaded: definitions/sg.yaml
  #
  # All the definitions are available at https://github.com/holidays/holidays
  module SG # :nodoc:
    def self.defined_regions
      [:sg]
    end

    def self.holidays_by_month
      {
                0 => [{:function => "easter(year)", :function_arguments => [:year], :function_modifier => -2, :name => "Good Friday", :regions => [:sg]}],
      1 => [{:mday => 1, :observed => "to_weekday_if_weekend(date)", :observed_arguments => [:date], :name => "New Year's Day", :regions => [:sg]}],
      2 => [{:mday => 14, :type => :informal, :name => "Valentine's Day", :regions => [:sg]},
            {:mday => 15, :type => :informal, :name => "Total Defence Day", :regions => [:sg]}],
      5 => [{:mday => 1, :name => "Labour Day", :regions => [:sg]}],
      8 => [{:mday => 9, :observed => "to_weekday_if_weekend(date)", :observed_arguments => [:date], :name => "National Day", :regions => [:sg]}],
      12 => [{:mday => 25, :observed => "to_weekday_if_weekend(date)", :observed_arguments => [:date], :name => "Christmas Day", :regions => [:sg]}]
      }
    end

    def self.custom_methods
      {
          
      }
    end
  end
end
