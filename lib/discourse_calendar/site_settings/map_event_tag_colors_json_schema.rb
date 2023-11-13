# frozen_string_literal: true

module DiscourseCalendar
  module SiteSettings
    class MapEventTagColorsJsonSchema
      def self.schema
        @schema ||= {
          type: "array",
          uniqueItems: true,
          items: {
            type: "object",
            title: "Color Mapping",
            properties: {
              type: {
                type: "string",
                description: "Type of mapping (tag or category)",
                enum: ["tag", "category"]
              },
              slug: {
                type: "string",
                description: "Slug of the tag or category"
              },
              color: {
                type: "string",
                description: "Color associated with the tag or category",
                pattern: "^#(?:[0-9a-fA-F]{3}){1,2}$"
              }
            },
            required: ["slug", "type", "color"]
          }
        }
      end
    end
  end
end
