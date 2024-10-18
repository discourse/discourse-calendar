# frozen_string_literal: true

describe "Post event", type: :system do
  fab!(:admin)
  fab!(:user) { Fabricate(:admin, username: "jane") }
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

    page.find(".more-dropdown").click
    page.find(".close-event").click
    page.find("#dialog-holder .btn-primary").click

    expect(page).to have_css(".discourse-post-event .status-and-creators .status.closed")

    # click on a different button to ensure more dropdown is collapsed before reopening
    page.find(".btn-primary.create").click
    page.find(".more-dropdown").click
    page.find(".open-event").click
    page.find("#dialog-holder .btn-primary").click

    expect(page).to have_css(".discourse-post-event .status-and-creators .status.public")

    page.find(".going-button").click
    page.find(".event-invitees .show-all").click
    page.find(".d-modal input.filter").fill_in(with: "jan")
    page.find(".d-modal .add-invitee").click

    topic_page = PageObjects::Pages::Topic.new

    topic = Topic.find(topic_page.current_topic_id)

    event = topic.posts.first.event

    expect(event.invitees.count).to eq(2)
  end
end
