# encoding: utf-8
require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'

# This file is generated by the Ruby Holiday gem.
#
# Definitions loaded: definitions/id.yaml
class IdDefinitionTests < Test::Unit::TestCase  # :nodoc:

  def test_id
    assert_equal "Good Friday", (Holidays.on(Date.civil(2022, 4, 15), [:id])[0] || {})[:name]

  end
end
