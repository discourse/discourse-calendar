# frozen_string_literal: true

require "rails_helper"
require_relative '../fabricators/event_fabricator'

module DiscoursePostEvent
  describe EventsController do
    fab!(:user) { Fabricate(:user, admin: true) }
    fab!(:topic) { Fabricate(:topic, user: user) }
    fab!(:post1) { Fabricate(:post, user: user, topic: topic) }
    fab!(:invitee1) { Fabricate(:user) }
    fab!(:invitee2) { Fabricate(:user) }

    before do
      SiteSetting.queue_jobs = false
      SiteSetting.displayed_invitees_limit = 3
      SiteSetting.discourse_post_event_enabled = true
    end

    context 'when a post exists' do
      fab!(:invitee3) { Fabricate(:user) }
      fab!(:invitee4) { Fabricate(:user) }
      fab!(:invitee5) { Fabricate(:user) }
      fab!(:group) {
        Fabricate(:group).tap do |g|
          g.add(invitee2)
          g.add(invitee3)
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

      it 'accepts user and group invitees' do
        invitees = [invitee1.username, group.name]

        post '/discourse-post-event/events.json', params: {
          event: {
            id: post1.id,
            raw_invitees: invitees,
            starts_at: 2.days.from_now,
            status: Event.statuses[:private],
            display_invitees: Event.display_invitees_options[:everyone]
          }
        }

        expect(response.status).to eq(200)
        sample_invitees = response.parsed_body['event']['sample_invitees']
        expect(sample_invitees.map { |i| i['user']['id'] }).to match_array([user.id, invitee1.id, group.group_users.first.user.id])
        raw_invitees = response.parsed_body['event']['raw_invitees']
        expect(raw_invitees).to match_array(invitees)
      end

      it 'accepts one user invitee' do
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
        expect(sample_invitees[0]['user']['username']).to eq(user.username)
        expect(sample_invitees[1]['user']['username']).to eq(invitee1.username)
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
            display_invitees: Event.display_invitees_options[:everyone],
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
            raw_invitees: [
              invitee1.username,
              invitee2.username,
              invitee3.username,
              invitee4.username,
              invitee5.username,
            ],
            starts_at: 2.days.from_now,
          }
        }

        expect(response.status).to eq(200)
        sample_invitees = response.parsed_body['event']['sample_invitees']
        expect(sample_invitees.map { |i| i['user']['username'] }).to match_array([user.username, invitee1.username, invitee2.username])
      end

      context 'when a event exists' do
        fab!(:event) { Fabricate(:event, post: post1) }

        context 'when we update the event' do
          context 'when status changes from standalone to private' do
            it 'changes the status, raw_invitees and invitees' do
              event.update!(status: Event.statuses[:standalone])

              put "/discourse-post-event/events/#{event.id}.json", params: {
                event: {
                  status: Event.statuses[:private].to_s,
                  raw_invitees: [invitee1.username]
                }
              }

              event.reload

              expect(event.status).to eq(Event.statuses[:private])
              expect(event.raw_invitees).to eq([invitee1.username])
              expect(event.invitees.pluck(:user_id)).to match_array([invitee1.id])
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
                raw_invitees: [invitee1.username]
              )
              event.fill_invitees!

              event.reload

              expect(event.invitees.pluck(:user_id)).to eq([invitee1.id])
              expect(event.raw_invitees).to eq([invitee1.username])

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
                raw_invitees: [invitee1.username]
              )
              event.fill_invitees!

              event.reload

              expect(event.invitees.pluck(:user_id)).to eq([invitee1.id])
              expect(event.raw_invitees).to eq([invitee1.username])

              put "/discourse-post-event/events/#{event.id}.json", params: {
                event: {
                  status: Event.statuses[:public].to_s
                }
              }

              event.reload

              expect(event.status).to eq(Event.statuses[:public])
              expect(event.raw_invitees).to eq([])
              expect(event.invitees.pluck(:user_id)).to eq([invitee1.id])
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
                  raw_invitees: [invitee1.username]
                }
              }

              event.reload

              expect(event.status).to eq(Event.statuses[:private])
              expect(event.raw_invitees).to eq([invitee1.username])
              expect(event.invitees.pluck(:user_id)).to eq([invitee1.id])
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
          fab!(:lurker) { Fabricate(:user) }

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
