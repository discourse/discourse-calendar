# frozen_string_literal: true
require "rails_helper"

describe DiscoursePostEvent::EventSummarySerializer do
  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:event) { Fabricate(:event, post: post) }

  it "returns the event summary" do
    json = DiscoursePostEvent::EventSummarySerializer.new(event, scope: Guardian.new).as_json
    summary = json[:event_summary]
    expect(summary[:starts_at]).to eq(event.starts_at)
    expect(summary[:ends_at]).to eq(event.ends_at)
    expect(summary[:timezone]).to eq(event.timezone)
    expect(summary[:name]).to eq(event.name)
    expect(summary[:post][:url]).to eq(post.url)
    expect(summary[:post][:topic][:title]).to eq(topic.title)
    expect(summary[:category_id]).to eq(category.id)
  end
end
