# encoding: utf-8
require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'

# This file is generated by the Ruby Holiday gem.
#
# Definitions loaded: definitions/ae.yaml
class AeDefinitionTests < Test::Unit::TestCase  # :nodoc:

  def test_ae
    assert_equal "New Year's Day", (Holidays.on(Date.civil(2024, 1, 1), [:ae], [:informal])[0] || {})[:name]

    assert_equal "Commemoration Day", (Holidays.on(Date.civil(2024, 12, 1), [:ae], [:informal])[0] || {})[:name]

    assert_equal "National Day", (Holidays.on(Date.civil(2024, 12, 2), [:ae], [:informal])[0] || {})[:name]

    assert_equal "National Day (Day 2)", (Holidays.on(Date.civil(2024, 12, 3), [:ae], [:informal])[0] || {})[:name]

  end
end
