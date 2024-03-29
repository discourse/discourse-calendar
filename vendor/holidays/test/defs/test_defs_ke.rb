# encoding: utf-8
require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'

# This file is generated by the Ruby Holiday gem.
#
# Definitions loaded: definitions/ke.yaml
class KeDefinitionTests < Test::Unit::TestCase  # :nodoc:

  def test_ke
    assert_equal "Good Friday", (Holidays.on(Date.civil(2008, 3, 21), [:ke])[0] || {})[:name]

    assert_equal "Easter Monday", (Holidays.on(Date.civil(2008, 3, 24), [:ke])[0] || {})[:name]

    assert_equal "New Year's Day", (Holidays.on(Date.civil(2008, 1, 1), [:ke])[0] || {})[:name]

    assert_equal "Labour Day", (Holidays.on(Date.civil(2008, 5, 1), [:ke])[0] || {})[:name]

    assert_equal "Madaraka Day", (Holidays.on(Date.civil(2019, 6, 1), [:ke])[0] || {})[:name]

    assert_equal "Huduma Day", (Holidays.on(Date.civil(2018, 10, 10), [:ke])[0] || {})[:name]

    assert_equal "Mashujaa Day", (Holidays.on(Date.civil(2018, 10, 20), [:ke])[0] || {})[:name]

    assert_equal "Jamhuri Day", (Holidays.on(Date.civil(2019, 12, 12), [:ke])[0] || {})[:name]

    assert_equal "Christmas Day", (Holidays.on(Date.civil(2008, 12, 25), [:ke])[0] || {})[:name]

    assert_equal "Utamaduni Day", (Holidays.on(Date.civil(2018, 12, 26), [:ke])[0] || {})[:name]

  end
end
