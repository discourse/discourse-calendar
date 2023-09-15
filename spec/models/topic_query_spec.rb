require "topic_view"

RSpec.describe TopicQuery do
  Event ||= DiscoursePostEvent::Event
  describe "sorts events" do
    let(:user) { Fabricate(:user, admin: true) }
    let!(:notified_user) { Fabricate(:user) }
    let(:topic_1) { Fabricate(:topic, user: user) }
    let(:topic_2) { Fabricate(:topic, user: user) }
    let(:topic_3) { Fabricate(:topic, user: user) }
    let(:topic_4) { Fabricate(:topic, user: user) }
    let!(:post_1) { Fabricate(:post, topic: topic_1) }
    let!(:post_2) { Fabricate(:post, topic: topic_2) }
    let!(:post_3) { Fabricate(:post, topic: topic_3) }
    let!(:post_4) { Fabricate(:post, topic: topic_4) }

    let(:future_event_1) do
      Event.create!(
        id: post_1.id,
        original_starts_at: Time.now + 5.hours,
        original_ends_at: Time.now + 7.hours,
      )
    end
    let(:future_event_2) do
      Event.create!(
        id: post_2.id,
        original_starts_at: Time.now + 1.hours,
        original_ends_at: Time.now + 2.hours,
      )
    end
    let(:past_event_1) do
      Event.create!(
        id: post_3.id,
        original_starts_at: Time.now - 10.hours,
        original_ends_at: Time.now - 8.hours,
      )
    end
    let(:past_event_2) do
      Event.create!(
        id: post_4.id,
        original_starts_at: Time.now - 7.hours,
        original_ends_at: Time.now - 5.hours,
      )
    end

    it "upcoming events first, sorted by ascending order. expired events last, sorted by descending order" do
      ordered_topics =
        TopicQuery.new(nil, order_by_event_date: [topic_1, topic_2, topic_3, topic_4]).options[
          :order_by_event_date
        ]
      expect(ordered_topics).to eq([topic_1, topic_2, topic_3, topic_4])

      TopicQuery.remove_custom_filter(:order_by_event_date)
    end
  end
end
