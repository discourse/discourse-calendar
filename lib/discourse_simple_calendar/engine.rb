# frozen_string_literal: true

module ::DiscourseCalendar
  class Engine < ::Rails::Engine
    engine_name DiscourseCalendar::PLUGIN_NAME
    isolate_namespace DiscourseCalendar
  end
end
