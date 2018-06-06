require 'rails_helper'

describe 'post serializer' do
  before do
    SiteSetting.queue_jobs = false
  end

  it 'includes calendar details in the serializer' do
    raw = <<~MD
      [calendar]
      [/calendar]
    MD
    topic = Fabricate(:topic, first_post: create_post(raw: raw))

    op = topic.first_post

    raw = <<~MD
      Rome [date="2018-06-05" time="10:20"]
    MD
    post = create_post(raw: raw, topic: topic)

    op.reload

    json = PostSerializer.new(op, scope: Guardian.new).as_json
    accepted = json[:post][:calendar_details]

    expect(accepted.length).to eq(1)
  end
end
