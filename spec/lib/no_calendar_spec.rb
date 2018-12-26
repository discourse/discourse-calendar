require 'rails_helper'

describe 'No calendar' do
  before do
    SiteSetting.queue_jobs = false
  end

  describe 'creating topics and posts' do
    it 'works' do
      expect {
        raw = <<~MD
          An op with no calendar in raw
        MD
        op = create_post(raw: raw)
        topic = op.topic

        raw = <<~MD
          This is a post with no event
        MD
        post = create_post(topic: topic, raw: raw)

        raw = <<~MD
          This is a post revision with no event
        MD
        post.revise(post.user, raw: raw)
      }.to_not raise_error
    end
  end
end
