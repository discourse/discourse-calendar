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

      expect(page).to have_css(
        "#upcoming-events-calendar .fc-event-container",
        text: event.post.topic.title,
      )
    end
  end

  context "when event is recurring" do
    let(:fixed_time) { Time.utc(2025, 6, 2, 19, 00) }

    before do
      freeze_time(fixed_time)

      event.update!(
        original_starts_at: Time.utc(2025, 3, 18, 13, 00),
        timezone: "Australia/Brisbane",
        recurrence: "every_week",
        recurrence_until: 21.days.from_now,
      )
    end

    it "respects the until date" do
      page.driver.with_playwright_page { |pw_page| pw_page.clock.set_fixed_time(fixed_time) }
      visit("/upcoming-events")

      expect(page).to have_css(".fc-day-grid-event", count: 3)
      expect(page).to have_css(
        ".fc-week:nth-child(2) .fc-content-skeleton:nth-child(2)",
        text: event.post.topic.title,
      )
      expect(page).to have_css(
        ".fc-week:nth-child(3) .fc-content-skeleton:nth-child(2)",
        text: event.post.topic.title,
      )
      expect(page).to have_css(
        ".fc-week:nth-child(4) .fc-content-skeleton:nth-child(2)",
        text: event.post.topic.title,
      )
    end
  end
end
