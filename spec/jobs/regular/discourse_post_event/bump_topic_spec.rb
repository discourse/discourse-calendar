# frozen_string_literal: true

RSpec.describe Jobs::DiscoursePostEventBumpTopic do
  fab!(:user)
  fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  it "bumps a topic" do
    event = Fabricate(:event, post: Fabricate(:post))

    expect { described_class.new.execute(event_id: event.id) }.to change {
      event.post.topic.posts.count
    }.by(1)
  end

  it "does not bump the topic if the user is not allowed to post" do
    topic = Fabricate(:topic, category: private_category, user: user)
    event = Fabricate(:event, post: Fabricate(:post, topic: topic, user: user))

    expect { described_class.new.execute(event_id: event.id) }.not_to change { topic.posts.count }
  end

  it "does not execute if the event is invalid" do
    topic = Fabricate(:topic)
    Fabricate(:event, post: Fabricate(:post, topic: topic))

    expect { described_class.new.execute(event_id: 999) }.not_to change { topic.posts.count }
  end

  it "raises an error if event_id is missing" do
    expect { described_class.new.execute({}) }.to raise_error(Discourse::InvalidParameters)
  end
end
