# frozen_string_literal: true
require "rails_helper"

describe DiscoursePostEvent::EventDate do
  let(:user) { Fabricate(:user, admin: true) }
  let(:topic) { Fabricate(:topic, user: user) }
  let!(:first_post) { Fabricate(:post, topic: topic) }
  let(:second_post) { Fabricate(:post, topic: topic) }
  let!(:starts_at) { "2020-04-24 14:15:00" }
  let!(:ends_at) { "2020-04-24 16:15:00" }
  let!(:alt_starts_at) { "2020-04-25 17:15:25" }
  let!(:alt_ends_at) { "2020-04-25 19:15:25" }
  let!(:post_event) { Fabricate(:event, post: first_post, original_starts_at: starts_at) }
  let!(:event_date) { Fabricate(:event_date, event: post_event) }

  before do
    freeze_time DateTime.parse("2020-04-24 14:10")
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  describe "Event Date Ended?" do
    it "returns false if no end time has been specified" do
      expect(event_date.ended?).to eq(false)
    end
  end
end
