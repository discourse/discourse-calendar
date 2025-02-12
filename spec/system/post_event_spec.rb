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
    page.find(".discourse-post-event-more-menu-trigger").click
    page.find(".show-all-participants").click
    page.find(".d-modal input.filter").fill_in(with: "jan")
    page.find(".d-modal .add-invitee").click

    topic_page = PageObjects::Pages::Topic.new

    topic = Topic.find(topic_page.current_topic_id)

    event = topic.posts.first.event

    expect(event.invitees.count).to eq(2)
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
    page.find(".toolbar-popup-menu-options .dropdown-select-box-header").click
    page.find(
      ".toolbar-popup-menu-options [data-name='#{I18n.t("js.discourse_post_event.builder_modal.attach")}']",
    ).click
    page.find(".d-modal input[name=status][value=private]").click
    page.find(".d-modal input.group-selector").fill_in(with: "test_")
    page.find(".autocomplete.ac-group").click
    page.find(".d-modal .custom-field-input").fill_in(with: "custom value")
    page.find(".d-modal .btn-primary").click
    composer.submit
    page.find(".discourse-post-event-more-menu-trigger").click
    page.find(".edit-event").click

    expect(page.find(".d-modal input[name=status][value=private]").checked?).to eq(true)
    expect(page.find(".d-modal")).to have_text("test_group")
    expect(page.find(".d-modal .custom-field-input").value).to eq("custom value")
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
