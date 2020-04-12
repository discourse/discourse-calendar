# frozen_string_literal: true

require "rails_helper"
require_relative '../fabricators/event_fabricator'

module DiscoursePostEvent
  describe EventsController do
    before do
      Jobs.run_immediately!
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      SiteSetting.displayed_invitees_limit = 3
    end

    let(:user) { Fabricate(:user, admin: true) }
    let(:topic) { Fabricate(:topic, user: user) }
    let(:post1) { Fabricate(:post, user: user, topic: topic) }
    let(:invitee1) { Fabricate(:user) }
    let(:invitee2) { Fabricate(:user) }

    context 'when a post exists' do
      let(:invitee3) { Fabricate(:user) }
      let(:invitee4) { Fabricate(:user) }
      let(:invitee5) { Fabricate(:user) }
      let(:group) {
        Fabricate(:group).tap do |g|
          g.add(invitee2)
          g.add(invitee3)
          g.save!
        end
      }

      let(:large_group) {
        Fabricate(:group).tap do |g|
          g.add(invitee2)
          g.add(invitee3)
          g.add(invitee4)
          g.add(invitee5)
          g.save!
        end
      }

      before do
        sign_in(user)
      end

      it 'creates an event' do
        post '/discourse-post-event/events.json', params: {
          event: {
            id: post1.id,
            starts_at: 2.days.from_now,
          }
        }

        expect(response.status).to eq(200)
        expect(response.parsed_body['event']['id']).to eq(post1.id)
        expect(Event).to exist(id: post1.id)
      end

      it 'accepts group as invitees' do
        invitees = [group.name]

        post '/discourse-post-event/events.json', params: {
          event: {
            id: post1.id,
            raw_invitees: invitees,
            starts_at: 2.days.from_now,
            status: Event.statuses[:private]
          }
        }

        expect(response.status).to eq(200)
        sample_invitees = response.parsed_body['event']['sample_invitees']
        expect(sample_invitees.map { |i| i['user']['id'] }).to match_array([user.id] + group.group_users.map { |gu| gu.user.id })
        raw_invitees = response.parsed_body['event']['raw_invitees']
        expect(raw_invitees).to match_array(invitees)
      end

      it 'doesn’t accept one user invitee' do
        post '/discourse-post-event/events.json', params: {
          event: {
            id: post1.id,
            status: Event.statuses[:private],
            raw_invitees: [invitee1.username],
            starts_at: 2.days.from_now,
          }
        }

        expect(response.status).to eq(200)
        sample_invitees = response.parsed_body['event']['sample_invitees']
        expect(sample_invitees.map { |i| i['user']['id'] }).to match_array([user.id])
      end

      it 'accepts one group invitee' do
        post '/discourse-post-event/events.json', params: {
          event: {
            id: post1.id,
            status: Event.statuses[:private],
            raw_invitees: [group.name],
            starts_at: 2.days.from_now,
          }
        }

        expect(response.status).to eq(200)
        sample_invitees = response.parsed_body['event']['sample_invitees']
        expect(sample_invitees.map { |i| i['user']['username'] }).to match_array([user.username] + group.group_users.map(&:user).map(&:username))
      end

      it 'accepts no invitee' do
        post '/discourse-post-event/events.json', params: {
          event: {
            id: post1.id,
            raw_invitees: [],
            status: Event.statuses[:private],
            starts_at: 2.days.from_now,
          }
        }

        expect(response.status).to eq(200)
        sample_invitees = response.parsed_body['event']['sample_invitees']
        expect(sample_invitees.count).to eq(1)
        expect(sample_invitees[0]['user']['username']).to eq(user.username)
      end

      it 'limits displayed invitees' do
        post '/discourse-post-event/events.json', params: {
          event: {
            id: post1.id,
            status: Event.statuses[:private],
            raw_invitees: [large_group.name],
            starts_at: 2.days.from_now,
          }
        }

        expect(response.status).to eq(200)
        sample_invitees = response.parsed_body['event']['sample_invitees']
        expect(large_group.group_users.length).to eq(4)
        expect(sample_invitees.length).to eq(3)
      end

      context 'when a event exists' do
        let(:event) { Fabricate(:event, post: post1) }

        context 'when we update the event' do
          context 'when status changes from standalone to private' do
            it 'changes the status, raw_invitees and invitees' do
              event.update!(status: Event.statuses[:standalone])

              put "/discourse-post-event/events/#{event.id}.json", params: {
                event: {
                  status: Event.statuses[:private].to_s,
                  raw_invitees: [group.name]
                }
              }

              event.reload

              expect(event.status).to eq(Event.statuses[:private])
              expect(event.raw_invitees).to eq([group.name])
              expect(event.invitees.pluck(:user_id)).to match_array(group.group_users.map { |gu| gu.user.id })
            end
          end

          context 'when status changes from standalone to public' do
            it 'changes the status' do
              event.update!(status: Event.statuses[:standalone])

              put "/discourse-post-event/events/#{event.id}.json", params: {
                event: {
                  status: Event.statuses[:public].to_s
                }
              }

              event.reload

              expect(event.status).to eq(Event.statuses[:public])
              expect(event.raw_invitees).to eq([])
              expect(event.invitees).to eq([])
            end
          end

          context 'when status changes from private to standalone' do
            it 'changes the status' do
              event.update!(
                status: Event.statuses[:private],
                raw_invitees: [group.name]
              )
              event.fill_invitees!

              event.reload

              expect(event.invitees.pluck(:user_id)).to match_array(group.group_users.map { |gu| gu.user.id })
              expect(event.raw_invitees).to eq([group.name])

              put "/discourse-post-event/events/#{event.id}.json", params: {
                event: {
                  status: Event.statuses[:standalone].to_s
                }
              }

              event.reload

              expect(event.status).to eq(Event.statuses[:standalone])
              expect(event.raw_invitees).to eq([])
              expect(event.invitees).to eq([])
            end
          end

          context 'when status changes from private to public' do
            it 'changes the status, removes raw_invitees and keeps invitees' do
              event.update!(
                status: Event.statuses[:private],
                raw_invitees: [group.name]
              )
              event.fill_invitees!

              event.reload

              expect(event.invitees.pluck(:user_id)).to match_array(group.group_users.map { |gu| gu.user.id })
              expect(event.raw_invitees).to eq([group.name])

              put "/discourse-post-event/events/#{event.id}.json", params: {
                event: {
                  status: Event.statuses[:public].to_s
                }
              }

              event.reload

              expect(event.status).to eq(Event.statuses[:public])
              expect(event.raw_invitees).to eq([])
              expect(event.invitees.pluck(:user_id)).to match_array(group.group_users.map { |gu| gu.user.id })
            end
          end

          context 'when status changes from public to private' do
            it 'changes the status, removes raw_invitees and keeps invitees' do
              event.update!(status: Event.statuses[:public])
              event.create_invitees([
                { user_id: invitee1.id },
                { user_id: invitee2.id },
              ])
              event.reload

              expect(event.invitees.pluck(:user_id)).to match_array([invitee1.id, invitee2.id])
              expect(event.raw_invitees).to eq(nil)

              put "/discourse-post-event/events/#{event.id}.json", params: {
                event: {
                  status: Event.statuses[:private].to_s,
                  raw_invitees: [group.name]
                }
              }

              event.reload

              expect(event.status).to eq(Event.statuses[:private])
              expect(event.raw_invitees).to eq([group.name])
              expect(event.invitees.pluck(:user_id)).to match_array(group.group_users.map { |gu| gu.user.id })
            end
          end

          context 'when status changes from public to standalone' do
            it 'changes the status, removes invitees' do
              event.update!(
                status: Event.statuses[:public]
              )
              event.create_invitees([ { user_id: invitee1.id } ])
              event.reload

              expect(event.invitees.pluck(:user_id)).to eq([invitee1.id])
              expect(event.raw_invitees).to eq(nil)

              put "/discourse-post-event/events/#{event.id}.json", params: {
                event: {
                  status: Event.statuses[:standalone].to_s
                }
              }

              event.reload

              expect(event.status).to eq(Event.statuses[:standalone])
              expect(event.raw_invitees).to eq([])
              expect(event.invitees).to eq([])
            end
          end
        end

        context 'acting user has created the event' do
          it 'destroys a event' do
            expect(event.persisted?).to be(true)

            messages = MessageBus.track_publish do
              delete "/discourse-post-event/events/#{event.id}.json"
            end
            expect(messages.count).to eq(1)
            message = messages.first
            expect(message.channel).to eq("/discourse-post-event/#{event.post.topic_id}")
            expect(message.data[:id]).to eq(event.id)
            expect(response.status).to eq(200)
            expect(Event).to_not exist(id: event.id)
          end
        end

        context 'acting user has not created the event' do
          let(:lurker) { Fabricate(:user) }

          before do
            sign_in(lurker)
          end

          it 'doesn’t destroy the event' do
            expect(event.persisted?).to be(true)
            delete "/discourse-post-event/events/#{event.id}.json"
            expect(response.status).to eq(403)
            expect(Event).to exist(id: event.id)
          end

          it 'doesn’t update the event' do
            put "/discourse-post-event/events/#{event.id}.json", params: {
              event: {
                status: Event.statuses[:public],
              }
            }

            expect(response.status).to eq(403)
          end
        end
      end
    end
  end
end
