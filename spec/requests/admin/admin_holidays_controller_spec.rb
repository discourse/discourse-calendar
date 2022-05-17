# frozen_string_literal: true

require "rails_helper"

module Admin::DiscourseCalendar
  describe AdminHolidaysController do
    fab!(:admin) { Fabricate(:user, admin: true) }
    fab!(:member) { Fabricate(:user) }

    before do
      SiteSetting.calendar_enabled = calendar_enabled
    end

    describe "#index" do
      context "when the calendar plugin is enabled" do
        let(:calendar_enabled) { true }

        context "when an admin is signed in" do
          before do
            sign_in(admin)
          end

          it "returns a list of holidays for a given region" do
            get "/admin/discourse-calendar/holiday-regions/mx/holidays.json"

            expect(response.parsed_body["holidays"]).to eq([
              { "date" => "2022-01-01", "name" => "Año nuevo", "regions" => ["mx"] },
              { "date" => "2022-02-07", "name" => "Día de la Constitución", "regions" => ["mx"] },
              { "date" => "2022-03-21", "name" => "Natalicio de Benito Juárez", "regions" => ["mx"] },
              { "date" => "2022-05-01", "name" => "Día del Trabajo", "regions" => ["mx"] },
              { "date" => "2022-09-15", "name" => "Grito de Dolores", "regions" => ["mx"] },
              { "date" => "2022-09-16", "name" => "Día de la Independencia", "regions" => ["mx"] },
              { "date" => "2022-11-21", "name" => "Día de la Revolución", "regions" => ["mx"] },
              { "date" => "2022-12-25", "name" => "Navidad", "regions" => ["mx"] }
            ])
          end

          it "returns a 422 and an error message for an invalid region" do
            get "/admin/discourse-calendar/holiday-regions/regionxyz/holidays.json"

            expect(response.status).to eq(422)
            expect(response.parsed_body["errors"]).to include(
              I18n.t("system_messages.discourse_calendar_holiday_region_invalid")
            )
          end
        end

        it "returns a 404 for a member" do
          sign_in(member)
          get "/admin/discourse-calendar/holiday-regions/mx/holidays.json"

          expect(response.status).to eq(404)
        end
      end

      context "when the calendar plugin is not enabled" do
        let(:calendar_enabled) { false }

        it "returns a 404 for an admin" do
          sign_in(admin)
          get "/admin/discourse-calendar/holiday-regions/mx/holidays.json"

          expect(response.status).to eq(404)
        end

        it "returns a 404 for a member" do
          sign_in(member)
          get "/admin/discourse-calendar/holiday-regions/mx/holidays.json"

          expect(response.status).to eq(404)
        end
      end
    end
  end
end
