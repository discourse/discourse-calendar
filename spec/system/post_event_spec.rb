# frozen_string_literal: true

describe "Post event", type: :system do
  fab!(:admin)
  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    sign_in(admin)
    visit "/new-topic"
  end

  it "can create, close, and open an event" do
    title = "My upcoming l33t event"
    tomorrow = (Time.zone.now + 1.day).strftime("%Y-%m-%d")

    composer.fill_title(title)

    composer.fill_content <<~MD
      [event start="#{tomorrow} 13:37" status="public"]
      [/event]
    MD

    composer.submit

    expect(page).to have_content(title)

    page.find("#more-dropdown").click
    page.find(".item-closeEvent").click
    page.find("#dialog-holder .btn-primary").click

    expect(page).to have_css(".discourse-post-event .status-and-creators .status.closed")

    page.find(".status-and-creators .status.closed").click
    # move active element away from dropdown
    # so that clicking it again below always opens the dropdown
    page.find("#more-dropdown").click
    page.find(".item-openEvent").click
    page.find("#dialog-holder .btn-primary").click

    expect(page).to have_css(".discourse-post-event .status-and-creators .status.public")
  end
end
