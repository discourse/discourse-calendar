# frozen_string_literal: true

require 'rails_helper'

describe Jobs::DiscoursePostEventBulkInvite do
  let(:user_1) { Fabricate(:user, admin: true) }
  let(:topic_1) { Fabricate(:topic, user: user_1) }
  let(:post_1) { Fabricate(:post, topic: topic_1) }
  let(:post_event_1) { Fabricate(:event, post: post_1, status: 'private') }

  before do
    freeze_time DateTime.parse('2018-11-10 12:00')
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  context '#execute' do
    context 'invalid params' do
      context 'no invitees given' do
        it 'raises an invalid parameters errors' do
          expect {
            subject.execute(current_user_id: 1, event_id: 1)
          }.to raise_error(Discourse::InvalidParameters)
        end
      end

      context 'no current_user_id given' do
        it 'raises an invalid parameters errors' do
          expect {
            subject.execute(invitees: [{ identifier: 'bob', attendance: 'going' }], event_id: 1)
          }.to raise_error(Discourse::InvalidParameters)
        end
      end

      context 'no event_id given' do
        it 'raises an invalid parameters errors' do
          expect {
            subject.execute(invitees: [{ identifier: 'bob', attendance: 'going' }], current_user_id: 1)
          }.to raise_error(Discourse::InvalidParameters)
        end
      end
    end

    context 'valid params' do
      context 'current user can’t act on event' do
        let(:lurker) { Fabricate(:user) }

        it 'raises an error' do
          expect {
            subject.execute(event_id: post_event_1.id, invitees: [{ identifier: 'bob', attendance: 'going' }], current_user_id: lurker.id)
          }.to raise_error(Discourse::InvalidAccess)
        end
      end

      context 'current user can act on event' do
        let(:invitee_1) { Fabricate(:user) }
        let(:invitee_2) { Fabricate(:user) }
        let(:invitee_3) { Fabricate(:user) }
        let(:invitee_4) { Fabricate(:user) }
        let(:group_1) {
          Fabricate(:group).tap do |g|
            g.add(invitee_1)
            g.add(invitee_2)
            g.save!
          end
        }
        let(:valid_params) {
          {
            event_id: post_event_1.id,
            invitees: [
              { 'identifier' => group_1.name, 'attendance' => 'not_going' },
              { 'identifier' => invitee_3.username, 'attendance' => 'interested' },
              { 'identifier' => invitee_4.username, 'attendance' => 'going' },
              { 'identifier' => 'non_existent', 'attendance' => 'going' },
            ],
            current_user_id: user_1.id
          }
        }

        context 'the event is private' do
          it 'creates the invitees' do
            SystemMessage.expects(:create_from_system_user).with(user_1, :discourse_post_event_bulk_invite_failed, {
              processed: 1,
              failed: 3,
              logs: "[#{Time.zone.now}] Couldn't find user or group: '#{invitee_3.username}' or the groups provided contained no users. Note that public events can't bulk invite groups. And other events can't bulk invite usernames.\n[#{Time.zone.now}] Couldn't find user or group: '#{invitee_4.username}' or the groups provided contained no users. Note that public events can't bulk invite groups. And other events can't bulk invite usernames.\n[#{Time.zone.now}] Couldn't find user or group: 'non_existent' or the groups provided contained no users. Note that public events can't bulk invite groups. And other events can't bulk invite usernames."
            }).once

            subject.execute(valid_params)

            invitee_klass = DiscoursePostEvent::Invitee

            expect(invitee_klass.count).to eq(2)
            expect(invitee_klass.find_by(user_id: invitee_1.id).status).to eq(invitee_klass.statuses[:not_going])
            expect(invitee_klass.find_by(user_id: invitee_2.id).status).to eq(invitee_klass.statuses[:not_going])
            expect(invitee_klass.find_by(user_id: invitee_3)).to eq(nil)
            expect(invitee_klass.find_by(user_id: invitee_4)).to eq(nil)
          end

          it 'removes the invitee if set to unknown' do
            subject.execute(valid_params)

            invitee_klass = DiscoursePostEvent::Invitee

            expect(invitee_klass.count).to eq(2)
            expect(invitee_klass.find_by(user_id: group_1.users[0].id).status).to be(invitee_klass.statuses[:not_going])
            expect(invitee_klass.find_by(user_id: group_1.users[1].id).status).to be(invitee_klass.statuses[:not_going])

            subject.execute(
              event_id: post_event_1.id,
              invitees: [
                { 'identifier' => group_1.name, 'attendance' => 'unknown' },
              ],
              current_user_id: user_1.id
            )

            expect(invitee_klass.count).to eq(0)
            expect(invitee_klass.find_by(user_id: group_1.users[0].id)).to be(nil)
            expect(invitee_klass.find_by(user_id: group_1.users[1].id)).to be(nil)
          end

          it 'sets the attendance to going by default' do
            SystemMessage.expects(:create_from_system_user).with(user_1, :discourse_post_event_bulk_invite_succeeded, {
              processed: 1
            })

            invitee_klass = DiscoursePostEvent::Invitee

            subject.execute(
              event_id: post_event_1.id,
              invitees: [
                { 'identifier' => group_1.name },
              ],
              current_user_id: user_1.id
            )

            expect(invitee_klass.count).to eq(2)
            expect(invitee_klass.find_by(user_id: group_1.users[0].id).status).to eq(invitee_klass.statuses[:going])
            expect(invitee_klass.find_by(user_id: group_1.users[1].id).status).to eq(invitee_klass.statuses[:going])
          end
        end

        context 'the event is public' do
          before do
            post_event_1.update_with_params!(status: 1)
          end

          it 'creates the invitees' do
            SystemMessage.expects(:create_from_system_user).with(user_1, :discourse_post_event_bulk_invite_failed, {
              processed: 2,
              failed: 2,
              logs: "[#{Time.zone.now}] Couldn't find user or group: '#{group_1.name}' or the groups provided contained no users. Note that public events can't bulk invite groups. And other events can't bulk invite usernames.\n[#{Time.zone.now}] Couldn't find user or group: 'non_existent' or the groups provided contained no users. Note that public events can't bulk invite groups. And other events can't bulk invite usernames."
            }).once

            subject.execute(valid_params)

            invitee_klass = DiscoursePostEvent::Invitee

            expect(invitee_klass.count).to eq(2)
            expect(invitee_klass.find_by(user_id: invitee_1)).to eq(nil)
            expect(invitee_klass.find_by(user_id: invitee_2)).to eq(nil)
            expect(invitee_klass.find_by(user_id: invitee_3.id).status).to eq(invitee_klass.statuses[:interested])
            expect(invitee_klass.find_by(user_id: invitee_4.id).status).to eq(invitee_klass.statuses[:going])
          end
        end
      end
    end
  end
end
