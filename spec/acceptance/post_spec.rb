# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'
require_relative '../fabricators/event_fabricator'


def create_post_with_event(user, extra_raw)
  start = Time.now.utc.iso8601(3)

  PostCreator.create!(
    user,
    title: "Sell a boat party ##{SecureRandom.alphanumeric}",
    raw: "[wrap=event start=\"#{start}\" #{extra_raw}]\n[/wrap]",
  )
end

describe Post do
  Event ||= DiscoursePostEvent::Event

  before do
    freeze_time
    SiteSetting.queue_jobs = false
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  let(:user) { Fabricate(:user, admin: true) }
  let(:topic) { Fabricate(:topic, user: user) }
  let(:post1) { Fabricate(:post, topic: topic) }
  let(:post_event) { Fabricate(:event, post: post1) }

  context 'when a post is updated' do
    context 'when the post has a valid event' do
      context 'when the event markup is removed' do
        it 'destroys the associated event' do
          start = Time.now.utc.iso8601(3)

          post = PostCreator.create!(
            user,
            title: 'Sell a boat party',
            raw: "[wrap=event start=\"#{start}\"]\n[/wrap]",
          )

          expect(post.reload.event.persisted?).to eq(true)

          revisor = PostRevisor.new(post, post.topic)
          revisor.revise!(user, raw: 'The event is over. Come back another day.')

          expect(post.reload.event).to be(nil)
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
            raw: "[wrap=event start=\"#{start}\"]\n[/wrap]",
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
          expect(post.event.raw_invitees).to eq([])

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
            raw: "[wrap=event start=\"#{start}\"]\n[/wrap]",
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
              raw: "[wrap=event start=\"#{start}\"]\n[/wrap]",
            )
          }.to(
            raise_error(ActiveRecord::RecordNotSaved)
              .with_message(I18n.t("discourse_post_event.errors.models.event.acting_user_not_allowed_to_create_event"))
          )
        end
      end
    end

    context 'when the post contains one invalid event' do
      context 'when start is not provided or is invalid' do
        it 'raises an error' do
          expect {
            PostCreator.create!(
              user,
              title: 'Sell a boat party',
              raw: "[wrap=event end=\"1\"]\n[/wrap]",
            )
          }.to(
            raise_error(ActiveRecord::RecordNotSaved)
              .with_message(I18n.t("discourse_post_event.errors.models.event.start_must_be_present_and_a_valid_date"))
          )

          expect {
            PostCreator.create!(
              user,
              title: 'Sell a boat party',
              raw: "[wrap=event start=\"x\"]\n[/wrap]",
            )
          }.to(
            raise_error(ActiveRecord::RecordNotSaved)
              .with_message(I18n.t("discourse_post_event.errors.models.event.start_must_be_present_and_a_valid_date"))
          )
        end
      end

      context 'when end is provided and is invalid' do
        it 'raises an error' do
          expect {
            PostCreator.create!(
              user,
              title: 'Sell a boat party',
              raw: "[wrap=event start=\"#{Time.now.utc.iso8601(3)}\" end=\"d\"]\n[/wrap]",
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
            raw: <<-TXT
[wrap=event start=\"#{Time.now.utc.iso8601(3)}\"][/wrap]

[wrap=event start=\"#{Time.now.utc.iso8601(3)}\"][/wrap]
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
