# frozen_string_literal: true

describe "Upcoming Events", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:category)
  fab!(:event)
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    sign_in(admin)
  end

  context "when user is signed in" do
    before { sign_in(admin) }

    it "shows the upcoming events" do
      visit("/upcoming-events")
      expect(page).to have_css("#upcoming-events-calendar")

      calendar = find("#upcoming-events-calendar")
      expect(calendar).to have_css(".fc-event-container")
    end
  end
end
