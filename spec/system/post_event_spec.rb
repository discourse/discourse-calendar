# frozen_string_literal: true

describe "Post event", type: :system do
  fab!(:admin)
  fab!(:user) { Fabricate(:admin, username: "jane") }
  fab!(:group) { Fabricate(:group, name: "test_group") }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:post_event_page) { PageObjects::Pages::DiscourseCalendar::PostEvent.new }
  let(:bulk_invite_modal_page) { PageObjects::Pages::DiscourseCalendar::BulkInviteModal.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_allowed_custom_fields = "custom"
    sign_in(admin)
  end

  context "when showing local time", timezone: "Australia/Brisbane" do
    it "correctly shows month/day" do
      page.driver.with_playwright_page do |pw_page|
        pw_page.clock.install(time: Time.new(2025, 6, 5, 22, 0, 0))
      end

      post =
        PostCreator.create(
          admin,
          title: "My test meetup event",
          raw:
            "[event showLocalTime='true' start='2025-09-07 17:30' start='2025-09-07 18:30' timezone='Europe/Paris']\n[/event]",
        )

      visit(post.topic.url)

      expect(page).to have_css(".event-date .month", text: "SEP")
      expect(page).to have_css(".event-date .day", text: "7")
    end

    it "shows correct date" do
      post =
        PostCreator.create(
          admin,
          title: "My test meetup event",
          raw: "[event timezone='Japan' showLocalTime='true' start='2222-02-22 14:22']\n[/event]",
        )

      visit(post.topic.url)

      expect(page).to have_css(".discourse-local-date", text: "Japan")
    end
  end

  it "safely renders event name" do
    post =
      PostCreator.create(
        admin,
        title: "My test meetup event",
        raw: "[event name=':cat: <script>alert(1);</script>' start='2222-02-22 00:00']\n[/event]",
      )

    visit(post.topic.url)

    expect(page).to have_css(".event-info .name img.emoji[title='cat']")
    expect(page).to have_css(".event-info .name", text: "<script>alert(1);</script>")
  end

  it "can create, close, and open an event" do
    visit "/new-topic"
    title = "My upcoming l33t event"
    tomorrow = (Time.zone.now + 1.day).strftime("%Y-%m-%d")

    composer.fill_title(title)

    composer.fill_content <<~MD
      [event start="#{tomorrow} 13:37" status="public"]
      [/event]
    MD

    composer.submit

    expect(page).to have_content(title)

    find(".more-dropdown").click
    find(".close-event").click
    find("#dialog-holder .btn-primary").click

    expect(page).to have_css(".discourse-post-event .status-and-creators .status.closed")

    # click on a different button to ensure more dropdown is collapsed before reopening
    find(".btn-primary.create").click
    find(".more-dropdown").click
    find(".open-event").click
    find("#dialog-holder .btn-primary").click

    expect(page).to have_css(".going-button")

    find(".going-button").click
    find(".discourse-post-event-more-menu-trigger").click
    find(".show-all-participants").click
    find(".d-modal input.filter").fill_in(with: "jan")
    find(".d-modal .add-invitee").click

    topic_page = PageObjects::Pages::Topic.new

    try_until_success do
      topic = Topic.find(topic_page.current_topic_id)

      event = topic.posts.first.event

      expect(event.invitees.count).to eq(2)
    end
  end

  it "does not show participants button when event is standalone" do
    post =
      PostCreator.create(
        admin,
        title: "My test meetup event",
        raw: "[event name='cool-event' status='standalone' start='2222-02-22 00:00' ]\n[/event]",
      )

    visit(post.topic.url)
    page.find(".discourse-post-event-more-menu-trigger").click
    expect(page).to have_no_css(".show-all-participants")
  end

  it "does not show 'send pm' button to the user who created the event" do
    post =
      PostCreator.create(
        admin,
        title: "My test meetup event",
        raw: "[event name='cool-event' status='public' start='2222-02-22 00:00' ]\n[/event]",
      )

    visit(post.topic.url)
    page.find(".discourse-post-event-more-menu-trigger").click
    expect(page).to have_no_css(".send-pm-to-creator")
  end

  it "persists changes" do
    visit "/new-topic"
    composer.fill_title("Test event with updates")
    dropdown = PageObjects::Components::SelectKit.new(".toolbar-popup-menu-options")
    dropdown.expand
    dropdown.select_row_by_name(I18n.t("js.discourse_post_event.builder_modal.attach"))
    find(".d-modal input[name=status][value=private]").click
    find(".d-modal input.group-selector").send_keys("test_")
    find(".autocomplete.ac-group").click
    find(".d-modal .custom-field-input").fill_in(with: "custom value")
    dropdown = PageObjects::Components::SelectKit.new(".available-recurrences")
    dropdown.expand
    dropdown.select_row_by_value("every_day")
    find(".d-modal .recurrence-until .date-picker").fill_in(with: "#{1.year.from_now.year}-12-30")
    find(".d-modal .btn-primary").click
    composer.submit

    expect(page).to have_css(".discourse-post-event.is-loaded")

    find(".discourse-post-event-more-menu-trigger").click
    find(".edit-event").click

    expect(find(".d-modal input[name=status][value=private]").checked?).to eq(true)
    expect(find(".d-modal")).to have_text("test_group")
    expect(find(".d-modal .custom-field-input").value).to eq("custom value")
    expect(page).to have_selector(".d-modal .recurrence-until .date-picker") do |input|
      input.value == "#{1.year.from_now.year}-12-30"
    end
  end

  context "when using bulk inline invite" do
    let!(:post) do
      PostCreator.create(
        admin,
        title: "My test meetup event",
        raw: "[event name='cool-event' status='public' start='2222-02-22 00:00' ]\n[/event]",
      )
    end

    fab!(:invitable_user_1) { Fabricate(:user) }
    fab!(:invitable_user_2) { Fabricate(:user) }

    it "can invite users to an event" do
      visit(post.topic.url)

      post_event_page.open_bulk_invite_modal
      bulk_invite_modal_page
        .set_invitee_at_row(invitable_user_1.username, "going", 1)
        .add_invitee
        .set_invitee_at_row(invitable_user_2.username, "not_going", 2)
        .send_invites

      expect(bulk_invite_modal_page).to be_closed
    end
  end
end
