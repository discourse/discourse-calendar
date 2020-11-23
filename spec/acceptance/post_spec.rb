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

  context 'public event' do
    let(:post_1) { Fabricate(:post) }
    let(:event_1) { Fabricate(:event, post: post_1, raw_invitees: ['trust_level_0']) }

    context 'when a post is updated' do
      context 'when the post has a valid event' do
        context 'when the event markup is removed' do
          it 'destroys the associated event' do
            start = Time.now.utc.iso8601(3)

            post = create_post_with_event(user)

            expect(post.reload.event.persisted?).to eq(true)

            revisor = PostRevisor.new(post, post.topic)
            revisor.revise!(
              user,
              raw: 'The event is over. Come back another day.'
            )

            expect(post.reload.event).to be(nil)
          end
        end

        context 'when event is on going' do
          let(:going_user) { Fabricate(:user) }
          let(:interested_user) { Fabricate(:user) }

          before do
            SiteSetting.editing_grace_period = 1.minute
            PostActionNotifier.enable
            SiteSetting.discourse_post_event_edit_notifications_time_extension =
              180
          end

          context 'when in edit grace period' do
            before do
              event_1.event_dates.first.update_columns(
                starts_at: 3.hours.ago, ends_at: 2.hours.ago
              )

              # clean state
              Notification.destroy_all
              interested_user.reload
              going_user.reload
            end

            it 'sends a post revision to going invitees' do
              Invitee.create_attendance!(going_user.id, post_1.id, :going)
              Invitee.create_attendance!(
                interested_user.id,
                post_1.id,
                :interested
              )

              expect {
                revisor = PostRevisor.new(post_1)
                revisor.revise!(
                  user,
                  { raw: post_1.raw + "\nWe are bout half way into our event!" },
                  revised_at: Time.now + 2.minutes
                )
              }.to change {
                going_user.notifications.count
              }.by(1)

              expect(interested_user.notifications.count).to eq(0)
            end
          end

          context 'when not edit grace period' do
            before do
              event_1.event_dates.first.update_columns(starts_at: 5.hours.ago)
            end

            it 'doesn’t send a post revision to anyone' do
              Invitee.create_attendance!(going_user.id, post_1.id, :going)
              Invitee.create_attendance!(
                interested_user.id,
                event_1.id,
                :interested
              )

              expect {
                revisor = PostRevisor.new(event_1.post)
                revisor.revise!(
                  user,
                  { raw: event_1.post.raw + "\nWe are bout half way into our event!" },
                  revised_at: Time.now + 2.minutes
                )
              }.to change {
                going_user.notifications.count + interested_user.notifications.count
              }.by(0)
            end
          end

          context 'an event with recurrence' do
            before do
              freeze_time Time.utc(2020, 8, 12, 16, 32)

              event_1.update_with_params!(
                recurrence: 'FREQ=WEEKLY;BYDAY=MO',
                original_starts_at: 3.hours.ago,
                original_ends_at: nil
              )

              Invitee.create_attendance!(going_user.id, event_1.id, :going)
              Invitee.create_attendance!(
                interested_user.id,
                event_1.id,
                :interested
              )

              event_1.reload

              # we stop processing jobs immediately at this point to prevent infinite loop
              # as future event ended job would finish now, trigger next recurrence, and anodther job...
              Jobs.run_later!
            end

            context 'when the event ends' do
              it 'sets the next dates' do
                event_1.update_with_params!(original_ends_at: Time.now)

                expect(event_1.starts_at.to_s).to eq('2020-08-19 13:32:00 UTC')
                expect(event_1.ends_at.to_s).to eq('2020-08-19 16:32:00 UTC')
              end

              it 'it removes status from every invitees' do
                expect(event_1.invitees.pluck(:status)).to match_array(
                  [Invitee.statuses[:going], Invitee.statuses[:interested]]
                )

                event_1.update_with_params!(original_ends_at: Time.now)
                expect(event_1.invitees.pluck(:status).compact).to eq([])
              end

              # that will be handled by new job, uncomment when finishedh
              it 'resends event creation notification to invitees' do
                expect { event_1.update_with_params!(original_ends_at: Time.now) }.to change {
                  going_user.notifications.count
                }.by(1)
              end
            end
          end

          context 'updating raw_invitees' do
            let(:lurker_1) { Fabricate(:user) }
            let(:group_1) { Fabricate(:group) }

            it 'doesn’t accept usernames' do
              event_1.update_with_params!(raw_invitees: [lurker_1.username])
              expect(event_1.raw_invitees).to eq(['trust_level_0'])
            end

            it 'doesn’t accept another group than trust_level_0' do
              event_1.update_with_params!(raw_invitees: [group_1.name])
              expect(event_1.raw_invitees).to eq(['trust_level_0'])
            end
          end

          context 'updating status to private' do
            it 'it changes the status and force invitees' do
              expect(event_1.raw_invitees).to eq(['trust_level_0'])
              expect(event_1.status).to eq(Event.statuses[:public])

              event_1.update_with_params!(status: Event.statuses[:private])

              expect(event_1.raw_invitees).to eq([])
              expect(event_1.status).to eq(Event.statuses[:private])
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

            post =
              PostCreator.create!(
                user,
                title: 'Sell a boat party',
                raw: "[event start=\"#{start}\"]\n[/event]"
              )

            expect(post.reload.persisted?).to eq(true)
            expect(post.event.persisted?).to eq(true)
            expect(post.event.original_starts_at).to eq_time(Time.parse(start))
          end

          it 'works with name attribute' do
            post = create_post_with_event(user, 'name="foo bar"').reload
            expect(post.event.name).to eq('foo bar')

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
            expect(post.event.status).to eq(
              DiscoursePostEvent::Event.statuses[:private]
            )

            post = create_post_with_event(user, 'status=""').reload
            expect(post.event.status).to eq(
              DiscoursePostEvent::Event.statuses[:standalone]
            )

            post = create_post_with_event(user, 'status=').reload
            expect(post.event.status).to eq(
              DiscoursePostEvent::Event.statuses[:standalone]
            )
          end

          it 'works with allowedGroups attribute' do
            post = create_post_with_event(user, 'allowedGroups="euro"').reload
            expect(post.event.raw_invitees).to eq([])

            post =
              create_post_with_event(user, 'status="public" allowedGroups="euro"')
                .reload
            expect(post.event.raw_invitees).to eq(%w[trust_level_0])

            post =
              create_post_with_event(
                user,
                'status="standalone" allowedGroups="euro"'
              ).reload
            expect(post.event.raw_invitees).to eq([])

            post =
              create_post_with_event(
                user,
                'status="private" allowedGroups="euro"'
              ).reload
            expect(post.event.raw_invitees).to eq(%w[euro])

            post =
              create_post_with_event(
                user,
                'status="private" allowedGroups="euro,america"'
              ).reload
            expect(post.event.raw_invitees).to match_array(%w[euro america])

            post =
              create_post_with_event(user, 'status="private" allowedGroups=""')
                .reload
            expect(post.event.raw_invitees).to eq([])

            post =
              create_post_with_event(user, 'status="private" allowedGroups=')
                .reload
            expect(post.event.raw_invitees).to eq([])
          end

          it 'works with reminders attribute' do
            post = create_post_with_event(user).reload
            expect(post.event.reminders).to eq(nil)

            post =
              create_post_with_event(user, 'reminders="1.hours,-3.days"').reload
            expect(post.event.reminders).to eq('1.hours,-3.days')
          end

          context 'with custom fields' do
            before do
              SiteSetting.discourse_post_event_allowed_custom_fields = 'foo-bar|bar'
            end

            it 'works with allowed custom fields' do
              post = create_post_with_event(user, 'fooBar="1"').reload
              expect(post.event.custom_fields['foo-bar']).to eq('1')

              post = create_post_with_event(user, 'bar="2"').reload
              expect(post.event.custom_fields['bar']).to eq('2')
            end

            it 'doesn’t work with not allowed custom fields' do
              post = create_post_with_event(user, 'baz="3"').reload
              expect(post.event.custom_fields['baz']).to eq(nil)
            end
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

            post =
              PostCreator.create!(
                user_with_rights,
                title: 'Sell a boat party',
                raw: "[event start=\"#{start}\"]\n[/event]"
              )

            expect(post.reload.persisted?).to eq(true)
            expect(post.event.persisted?).to eq(true)
            expect(post.event.original_starts_at).to eq_time(Time.parse(start))
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

            expect do
              PostCreator.create!(
                user_without_rights,
                title: 'Sell a boat party',
                raw: "[event start=\"#{start}\"]\n[/event]"
              )
            end.to(
              raise_error(ActiveRecord::RecordNotSaved).with_message(
                I18n.t(
                  'discourse_post_event.errors.models.event.acting_user_not_allowed_to_create_event'
                )
              )
            )
          end
        end
      end

      context 'when the post contains one invalid event' do
        context 'when start is invalid' do
          it 'raises an error' do
            expect do
              PostCreator.create!(
                user,
                title: 'Sell a boat party', raw: "[event start=\"x\"]\n[/event]"
              )
            end.to(
              raise_error(ActiveRecord::RecordNotSaved).with_message(
                I18n.t(
                  'discourse_post_event.errors.models.event.start_must_be_present_and_a_valid_date'
                )
              )
            )
          end
        end

        context 'when start is not provided or' do
          it 'is not cooked' do
            post =
              PostCreator.create!(
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
            expect do
              PostCreator.create!(
                user,
                title: 'Sell a boat party',
                raw:
                  "[event start=\"#{
                    Time.now.utc.iso8601(3)
                  }\" end=\"d\"]\n[/event]"
              )
            end.to(
              raise_error(ActiveRecord::RecordNotSaved).with_message(
                I18n.t(
                  'discourse_post_event.errors.models.event.end_must_be_a_valid_date'
                )
              )
            )
          end
        end
      end

      context 'when the post contains multiple events' do
        it 'raises an error' do
          expect do
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
          end.to(
            raise_error(ActiveRecord::RecordNotSaved).with_message(
              I18n.t('discourse_post_event.errors.models.event.only_one_event')
            )
          )
        end
      end
    end

    context 'when a post with an event is destroyed' do
      it 'sets deleted_at on the post_event' do
        expect(event_1.deleted_at).to be_nil

        PostDestroyer.new(user, event_1.post).destroy
        event_1.reload

        expect(event_1.deleted_at).to eq_time(Time.now)
      end
    end

    context 'when a post with an event is recovered' do
      it 'nullifies deleted_at on the post_event' do
        PostDestroyer.new(user, event_1.post).destroy

        expect(event_1.reload.deleted_at).to eq_time(Time.now)

        PostDestroyer.new(user, Post.with_deleted.find(event_1.id)).recover

        expect(event_1.reload.deleted_at).to be_nil
      end
    end
  end

  context 'private event' do
    before do
      freeze_time Time.utc(2020, 8, 12, 16, 32)
    end

    let(:invitee_1) { Fabricate(:user) }
    let(:invitee_2) { Fabricate(:user) }
    let(:group_1) {
      Fabricate(:group).tap do |g|
        g.add(invitee_1)
        g.add(invitee_2)
        g.save!
      end
    }
    let(:post_1) { Fabricate(:post) }
    let(:event_1) {
      Fabricate(
        :event,
        post: post_1,
        status: Event.statuses[:private],
        raw_invitees: [group_1.name],
        original_starts_at: 3.hours.ago,
        original_ends_at: nil
      )
    }

    context 'an event with recurrence' do
      let(:event_1) {
        Fabricate(
          :event,
          post: post_1,
          status: Event.statuses[:private],
          raw_invitees: [group_1.name],
          recurrence: 'FREQ=WEEKLY;BYDAY=MO',
          original_starts_at: 3.hours.ago,
          original_ends_at: nil
        )
      }

      before do
        Invitee.create_attendance!(invitee_1.id, event_1.id, :going)

        # we stop processing jobs immediately at this point to prevent infinite loop
        # as future event ended job would finish now, trigger next recurrence, and anodther job...
        Jobs.run_later!
      end

      context 'updating the end' do
        it 'resends event creation notification to invitees and possible invitees' do
          expect(event_1.invitees.count).to eq(1)

          expect { event_1.update_with_params!(original_ends_at: 2.hours.ago) }.to change {
            invitee_1.notifications.count + invitee_2.notifications.count
          }.by(2)
        end
      end
    end

    context 'updating raw_invitees' do
      let(:lurker_1) { Fabricate(:user) }
      let(:group_2) { Fabricate(:group) }

      it 'doesn’t accept usernames' do
        expect {
          event_1.update_with_params!(raw_invitees: [lurker_1.username])
        }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'accepts another group than trust_level_0' do
        event_1.update_with_params!(raw_invitees: [group_2.name])
        expect(event_1.raw_invitees).to eq([group_2.name])
      end
    end

    context 'updating status to public' do
      it 'it changes the status and force invitees' do
        expect(event_1.raw_invitees).to eq([group_1.name])
        expect(event_1.status).to eq(Event.statuses[:private])

        event_1.update_with_params!(status: Event.statuses[:public])

        expect(event_1.raw_invitees).to eq(['trust_level_0'])
        expect(event_1.status).to eq(Event.statuses[:public])
      end
    end
  end
end
