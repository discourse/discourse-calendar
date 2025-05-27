# frozen_string_literal: true

return if !defined?(Chat)

describe DiscoursePostEvent::ChatChannelSync do
  fab!(:user)
  fab!(:admin)
  fab!(:admin_post) { Fabricate(:post, user: admin) }

  it "is able to create a chat channel and sync members" do
    event = Fabricate(:event, chat_enabled: true, post: admin_post)

    expect(event.chat_channel_id).not_to be_nil
    expect(event.chat_channel.name).to eq(event.name)

    expect(event.chat_channel.user_chat_channel_memberships.count).to eq(1)
    expect(event.chat_channel.user_chat_channel_memberships.first.user_id).to eq(admin.id)

    event = event.reload
    event.create_invitees([user_id: user.id, status: DiscoursePostEvent::Invitee.statuses[:going]])
    event.save!

    expect(event.chat_channel.user_chat_channel_memberships.count).to eq(2)
  end
end
