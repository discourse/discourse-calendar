# frozen_string_literal: true
require "rails_helper"

describe DiscoursePostEvent::EventSerializer do
  Event ||= DiscoursePostEvent::Event
  Invitee ||= DiscoursePostEvent::Invitee
  EventSerializer ||= DiscoursePostEvent::EventSerializer

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  context "with a private event" do
    fab!(:private_event) { Fabricate(:event, post: post, status: Event.statuses[:private]) }
    fab!(:invitee_1) { Fabricate(:user) }
    fab!(:invitee_2) { Fabricate(:user) }
    fab!(:group_1) do
      Fabricate(:group).tap do |g|
        g.add(invitee_1)
        g.add(invitee_2)
        g.save!
      end
    end

    context "when some invited users have not rsvp-ed yet" do
      before do
        private_event.update_with_params!(raw_invitees: [group_1.name])
        Invitee.create_attendance!(invitee_1.id, private_event.id, :going)
        private_event.reload
      end

      it "returns the correct stats" do
        json = EventSerializer.new(private_event, scope: Guardian.new).as_json
        expect(json[:event][:stats]).to eq(going: 1, interested: 0, invited: 2, not_going: 0)
      end
    end
  end

  context "with a public event" do
    fab!(:event) { Fabricate(:event, post: post) }

    it "returns the event category's id" do
      json = EventSerializer.new(event, scope: Guardian.new).as_json
      expect(json[:event][:category_id]).to eq(category.id)
    end
  end

  context "when recurrent event" do
    before { freeze_time Time.utc(2023, 1, 1, 1, 1) } # Sunday
    let(:every_day_event) do
      Fabricate(
        :event,
        post: post,
        recurrence: "every_day",
        original_starts_at: "2023-01-01 15:00",
        original_ends_at: "2023-01-01 16:00",
      )
    end
    let(:every_week_event) do
      Fabricate(
        :event,
        post: post,
        recurrence: "every_week",
        original_starts_at: "2023-01-01 15:00",
        original_ends_at: "2023-01-01 16:00",
      )
    end
    let(:every_two_weeks_event) do
      Fabricate(
        :event,
        post: post,
        recurrence: "every_two_weeks",
        original_starts_at: "2023-01-01 15:00",
        original_ends_at: "2023-01-01 16:00",
      )
    end
    let(:every_four_weeks_event) do
      Fabricate(
        :event,
        post: post,
        recurrence: "every_four_weeks",
        original_starts_at: "2023-01-01 15:00",
        original_ends_at: "2023-01-01 16:00",
      )
    end
    let(:every_month_event) do
      Fabricate(
        :event,
        post: post,
        recurrence: "every_month",
        original_starts_at: "2023-01-01 15:00",
        original_ends_at: "2023-01-01 16:00",
      )
    end
    let(:every_weekday_event) do
      Fabricate(
        :event,
        post: post,
        recurrence: "every_weekday",
        original_starts_at: "2023-01-01 15:00",
        original_ends_at: "2023-01-01 16:00",
      )
    end

    it "returns next dates for the every day event" do
      json = EventSerializer.new(every_day_event, scope: Guardian.new).as_json
      expect(json[:event][:next_dates].length).to eq(365)
      expect(json[:event][:next_dates].last).to eq(
        {
          starts_at: "2024-01-01 15:00:00.000000000 +0000",
          ends_at: "2024-01-01 16:00:00.000000000 +0000",
        },
      )
    end

    it "returns next dates for the every week event" do
      json = EventSerializer.new(every_week_event, scope: Guardian.new).as_json
      expect(json[:event][:next_dates].length).to eq(52)
      expect(json[:event][:next_dates].last).to eq(
        {
          starts_at: "2023-12-31 15:00:00.000000000 +0000", # Sunday
          ends_at: "2023-12-31 16:00:00.000000000 +0000",
        },
      )
    end

    it "returns next dates for the every two weeks event" do
      json = EventSerializer.new(every_two_weeks_event, scope: Guardian.new).as_json
      expect(json[:event][:next_dates].length).to eq(26)
      expect(json[:event][:next_dates].last).to eq(
        {
          starts_at: "2023-12-31 15:00:00.000000000 +0000", # Sunday
          ends_at: "2023-12-31 16:00:00.000000000 +0000",
        },
      )
    end

    it "returns next dates for the every four weeks event" do
      json = EventSerializer.new(every_four_weeks_event, scope: Guardian.new).as_json
      expect(json[:event][:next_dates].length).to eq(13)
      expect(json[:event][:next_dates].last).to eq(
        {
          starts_at: "2023-12-31 15:00:00.000000000 +0000", # Sunday
          ends_at: "2023-12-31 16:00:00.000000000 +0000",
        },
      )
    end

    it "returns next dates for the every weekday event" do
      json = EventSerializer.new(every_weekday_event, scope: Guardian.new).as_json
      expect(json[:event][:next_dates].length).to eq(260)
      expect(json[:event][:next_dates].last).to eq(
        {
          starts_at: "2023-12-29 15:00:00.000000000 +0000", # Friday
          ends_at: "2023-12-29 16:00:00.000000000 +0000",
        },
      )
    end

    it "returns next dates for the every month event" do
      json = EventSerializer.new(every_month_event, scope: Guardian.new).as_json
      expect(json[:event][:next_dates].length).to eq(12)
      expect(json[:event][:next_dates].last).to eq(
        {
          starts_at: "2024-01-07 15:00:00.000000000 +0000", # Sunday
          ends_at: "2024-01-07 16:00:00.000000000 +0000",
        },
      )
    end
  end
end
