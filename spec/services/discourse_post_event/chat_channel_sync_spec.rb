# frozen_string_literal: true

return if !defined?(Chat)

describe DiscoursePostEvent::ChatChannelSync do
  fab!(:user)

  it "is able to create a chat channel and sync members" do
    event = Fabricate(:event, chat_enabled: true)

    expect(event.chat_channel_id).not_to be_nil
    expect(event.chat_channel.name).to eq(event.name)

    # not expecting system user or anyone else here
    expect(event.chat_channel.user_chat_channel_memberships.count).to eq(0)

    event.create_invitees([user_id: user.id, status: DiscoursePostEvent::Invitee.statuses[:going]])
    event.save!

    expect(event.chat_channel.user_chat_channel_memberships.count).to eq(1)
  end
end
