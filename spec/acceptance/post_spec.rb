# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'
require_relative '../fabricators/event_fabricator'

describe Post do
  Event ||= DiscoursePostEvent::Event
  Invitee ||= DiscoursePostEvent::Invitee

  before do
    freeze_time
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  let(:user) { Fabricate(:user, admin: true) }
  let(:topic) { Fabricate(:topic, user: user) }
  let(:post1) { Fabricate(:post, topic: topic) }
  let!(:post_event) { Fabricate(:event, post: post1, status: Event.statuses[:public]) }

  context 'when a post is updated' do
    context 'when the post has a valid event' do
      context 'when the event markup is removed' do
        it 'destroys the associated event' do
          start = Time.now.utc.iso8601(3)

          post = PostCreator.create!(
            user,
            title: 'Sell a boat party',
            raw: "[event start=\"#{start}\"]\n[/event]",
          )

          expect(post.reload.event.persisted?).to eq(true)

          revisor = PostRevisor.new(post, post.topic)
          revisor.revise!(user, raw: 'The event is over. Come back another day.')

          expect(post.reload.event).to be(nil)
        end
      end

      context 'when event is on going' do
        let(:going_user) { Fabricate(:user) }
        let(:interested_user) { Fabricate(:user) }
        let(:post_1) { create_post_with_event(user) }

        before do
          SiteSetting.editing_grace_period = 1.minute
          PostActionNotifier.enable
          SiteSetting.discourse_post_event_edit_notifications_time_extension = 180
        end

        context 'when in edit grace period' do
          before do
            post_1.reload.event.update_with_params!(starts_at: 3.hours.ago, ends_at: 2.hours.ago)
          end

          it 'sends a post revision to going invitees' do
            Invitee.create_attendance!(going_user.id, post_1.id, :going)
            Invitee.create_attendance!(interested_user.id, post_1.id, :interested)

            revisor = PostRevisor.new(post_1)
            revisor.revise!(
              user,
              { raw: post_1.raw + "\nWe are bout half way into our event!" },
              revised_at: Time.now + 2.minutes
            )

            expect(going_user.notifications.count).to eq(1)
            expect(interested_user.notifications.count).to eq(0)
          end
        end

        context 'when not edit grace period' do
          before do
            post_1.reload.event.update_with_params!(starts_at: 5.hours.ago)
          end

          it 'doesn’t send a post revision to anyone' do
            Invitee.create_attendance!(going_user.id, post_1.id, :going)
            Invitee.create_attendance!(interested_user.id, post_1.id, :interested)

            revisor = PostRevisor.new(post_1)
            revisor.revise!(
              user,
              { raw: post_1.raw + "\nWe are bout half way into our event!" },
              revised_at: Time.now + 2.minutes
            )

            expect(going_user.notifications.count).to eq(0)
            expect(interested_user.notifications.count).to eq(0)
          end
        end
      end
    end
  end

  context 'when a post is created' do
    context 'when the post contains one valid event' do
      context 'when the acting user is admin' do
        it 'creates the post event' do
          start = Time.now.utc.iso8601(3)

          post = PostCreator.create!(
            user,
            title: 'Sell a boat party',
            raw: "[event start=\"#{start}\"]\n[/event]",
          )

          expect(post.reload.persisted?).to eq(true)
          expect(post.event.persisted?).to eq(true)
          expect(post.event.starts_at).to eq_time(Time.parse(start))
        end

        it 'works with name attribute' do
          post = create_post_with_event(user, 'name="foo bar"').reload
          expect(post.event.name).to eq("foo bar")

          post = create_post_with_event(user, 'name=""').reload
          expect(post.event.name).to be_blank

          post = create_post_with_event(user, 'name=').reload
          expect(post.event.name).to be_blank
        end

        it 'works with url attribute' do
          url = 'https://www.discourse.org'

          post = create_post_with_event(user, "url=\"#{url}\"").reload
          expect(post.event.url).to eq(url)

          post = create_post_with_event(user, 'url=""').reload
          expect(post.event.url).to be_blank

          post = create_post_with_event(user, 'url=').reload
          expect(post.event.url).to be_blank
        end

        it 'works with status attribute' do
          post = create_post_with_event(user, 'status="private"').reload
          expect(post.event.status).to eq(DiscoursePostEvent::Event.statuses[:private])

          post = create_post_with_event(user, 'status=""').reload
          expect(post.event.status).to eq(DiscoursePostEvent::Event.statuses[:standalone])

          post = create_post_with_event(user, 'status=').reload
          expect(post.event.status).to eq(DiscoursePostEvent::Event.statuses[:standalone])
        end

        it 'works with allowedGroups attribute' do
          post = create_post_with_event(user, 'allowedGroups="euro"').reload
          expect(post.event.raw_invitees).to eq([])

          post = create_post_with_event(user, 'status="public" allowedGroups="euro"').reload
          expect(post.event.raw_invitees).to eq(['trust_level_0'])

          post = create_post_with_event(user, 'status="standalone" allowedGroups="euro"').reload
          expect(post.event.raw_invitees).to eq([])

          post = create_post_with_event(user, 'status="private" allowedGroups="euro"').reload
          expect(post.event.raw_invitees).to eq(['euro'])

          post = create_post_with_event(user, 'status="private" allowedGroups="euro,america"').reload
          expect(post.event.raw_invitees).to match_array(['euro', 'america'])

          post = create_post_with_event(user, 'status="private" allowedGroups=""').reload
          expect(post.event.raw_invitees).to eq([])

          post = create_post_with_event(user, 'status="private" allowedGroups=').reload
          expect(post.event.raw_invitees).to eq([])
        end

        it 'works with reminders attribute' do
          post = create_post_with_event(user).reload
          expect(post.event.reminders).to eq(nil)

          post = create_post_with_event(user, 'reminders="1.hours,-3.days"').reload
          expect(post.event.reminders).to eq('1.hours,-3.days')
        end
      end

      context 'when the acting user has rights to create events' do
        let(:user_with_rights) { Fabricate(:user) }
        let(:group) { Fabricate(:group, users: [user_with_rights]) }

        before do
          SiteSetting.discourse_post_event_allowed_on_groups = group.id.to_s
        end

        it 'creates the post event' do
          start = Time.now.utc.iso8601(3)

          post = PostCreator.create!(
            user_with_rights,
            title: 'Sell a boat party',
            raw: "[event start=\"#{start}\"]\n[/event]",
          )

          expect(post.reload.persisted?).to eq(true)
          expect(post.event.persisted?).to eq(true)
          expect(post.event.starts_at).to eq_time(Time.parse(start))
        end
      end

      context 'when the acting user doesn’t have rights to create events' do
        let(:user_without_rights) { Fabricate(:user) }
        let(:group) { Fabricate(:group, users: [user]) }

        before do
          SiteSetting.discourse_post_event_allowed_on_groups = group.id.to_s
        end

        it 'raises an error' do
          start = Time.now.utc.iso8601(3)

          expect {
            PostCreator.create!(
              user_without_rights,
              title: 'Sell a boat party',
              raw: "[event start=\"#{start}\"]\n[/event]",
            )
          }.to(
            raise_error(ActiveRecord::RecordNotSaved)
              .with_message(I18n.t("discourse_post_event.errors.models.event.acting_user_not_allowed_to_create_event"))
          )
        end
      end
    end

    context 'when the post contains one invalid event' do
      context 'when start is invalid' do
        it 'raises an error' do
          expect {
            PostCreator.create!(
              user,
              title: 'Sell a boat party',
              raw: "[event start=\"x\"]\n[/event]",
            )
          }.to(
            raise_error(ActiveRecord::RecordNotSaved)
              .with_message(I18n.t("discourse_post_event.errors.models.event.start_must_be_present_and_a_valid_date"))
          )
        end
      end

      context 'when start is not provided or' do
        it 'is not cooked' do
          post = PostCreator.create!(
            user,
            title: 'Sell a boat party',
            raw: <<~TXT
              [event end=\"1\"]
              [/event]
            TXT
          )

          expect(!post.cooked.include?('discourse-post-event')).to be(true)
        end
      end

      context 'when end is provided and is invalid' do
        it 'raises an error' do
          expect {
            PostCreator.create!(
              user,
              title: 'Sell a boat party',
              raw: "[event start=\"#{Time.now.utc.iso8601(3)}\" end=\"d\"]\n[/event]",
            )
          }.to(
            raise_error(ActiveRecord::RecordNotSaved)
              .with_message(I18n.t("discourse_post_event.errors.models.event.end_must_be_a_valid_date"))
          )
        end
      end
    end

    context 'when the post contains multiple events' do
      it 'raises an error' do
        expect {
          PostCreator.create!(
            user,
            title: 'Sell a boat party',
            raw: <<~TXT
              [event start=\"#{Time.now.utc.iso8601(3)}\"]
              [/event]

              [event start=\"#{Time.now.utc.iso8601(3)}\"]
              [/event]
            TXT
          )
        }.to(
          raise_error(ActiveRecord::RecordNotSaved)
            .with_message(I18n.t("discourse_post_event.errors.models.event.only_one_event"))
        )
      end
    end
  end

  context 'when a post with an event is destroyed' do
    it 'sets deleted_at on the post_event' do
      expect(post_event.deleted_at).to be_nil

      PostDestroyer.new(user, post_event.post).destroy
      post_event.reload

      expect(post_event.deleted_at).to eq_time(Time.now)
    end
  end

  context 'when a post with an event is recovered' do
    it 'nullifies deleted_at on the post_event' do
      post_id = post_event.post.id
      PostDestroyer.new(user, post_event.post).destroy

      expect(post_event.reload.deleted_at).to eq_time(Time.now)

      PostDestroyer.new(user, Post.with_deleted.find(post_id)).recover

      expect(post_event.reload.deleted_at).to be_nil
    end
  end
end
