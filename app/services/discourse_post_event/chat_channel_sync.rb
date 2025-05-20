# frozen_string_literal: true
#
module DiscoursePostEvent
  class ChatChannelSync
    def self.sync(event)
      return if !event.chat_enabled?

      ensure_chat_channel!(event) if !event.chat_channel_id
      sync_chat_channel_members!(event)
    end

    def self.sync_chat_channel_members!(event)
      missing_members_sql = <<~SQL
        SELECT user_id
        FROM discourse_post_event_invitees
        WHERE post_id = :post_id
        AND status in (:statuses)
        AND user_id NOT IN (
          SELECT user_id
          FROM user_chat_channel_memberships
          WHERE chat_channel_id = :chat_channel_id
        )
      SQL

      missing_user_ids =
        DB.query_single(
          missing_members_sql,
          post_id: event.post.id,
          statuses: [DiscoursePostEvent::Invitee.statuses[:going]],
          chat_channel_id: event.chat_channel_id,
        )

      if missing_user_ids.present?
        ActiveRecord::Base.transaction do
          missing_user_ids.each do |user_id|
            event.chat_channel.user_chat_channel_memberships.create!(
              user_id:,
              chat_channel_id: event.chat_channel_id,
              following: true,
            )
          end
        end
      end
    end

    def self.ensure_chat_channel!(event)
      name = event.name

      guardian = Guardian.new(Discourse.system_user)
      channel = nil
      Chat::CreateCategoryChannel.call(
        guardian:,
        params: {
          name:,
          category_id: event.post.topic.category_id,
        },
      ) do |result|
        on_success { channel = result.channel }
        on_failure { raise StandardError, result.inspect_steps }
      end

      # system user does not belong in the channel - this is awkward, we should be allowed to avoid
      channel.user_chat_channel_memberships.where(user_id: Discourse.system_user.id).destroy_all

      event.chat_channel_id = channel.id
    end
  end
end
