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

  context "when event is recurring" do
    let(:fixed_time) { Time.utc(2018, 6, 5, 9, 30) }

    before do
      freeze_time(fixed_time)

      event.update!(
        original_starts_at: fixed_time + 1.hour,
        recurrence: "every_day",
        recurrence_until: 3.days.from_now,
      )
    end

    it "respects the until date" do
      page.driver.with_playwright_page { |pw_page| pw_page.clock.set_fixed_time(fixed_time) }
      visit("/upcoming-events")

      expect(page).to have_css(".fc-day-grid-event", count: 3)
    end
  end
end
