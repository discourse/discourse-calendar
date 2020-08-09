# frozen_string_literal: true

require 'rails_helper'
require_relative '../fabricators/event_fabricator'

module DiscoursePostEvent
  describe InviteesController do
    before do
      SiteSetting.queue_jobs = false
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      sign_in(user)
    end

    let(:user) { Fabricate(:user, admin: true) }
    let(:topic_1) { Fabricate(:topic, user: user) }
    let(:post_1) { Fabricate(:post, user: user, topic: topic_1) }

    context 'when a post event exists' do
      context 'when an invitee exists' do
        let(:invitee1) { Fabricate(:user) }
        let(:post_event_2) {
          pe = Fabricate(:event, post: post_1)
          pe.create_invitees([{
            user_id: invitee1.id,
            status: Invitee.statuses[:going]
          }])
          pe
        }

        context "updating invitee" do
          it 'updates its status' do
            invitee = post_event_2.invitees.first

            expect(invitee.status).to eq(0)

            put "/discourse-post-event/events/#{post_event_2.id}/invitees/#{invitee.id}.json", params: {
              invitee: {
                status: 'interested'
              }
            }

            invitee.reload

            expect(invitee.status).to eq(1)
            expect(invitee.post_id).to eq(post_1.id)
          end
        end

        context 'destroying invitee' do
          context 'acting user can act on discourse event' do
            it 'destroys the invitee' do
              invitee = post_event_2.invitees.first
              delete "/discourse-post-event/events/#{post_event_2.id}/invitees/#{invitee.id}.json"
              expect(Invitee.where(id: invitee.id).length).to eq(0)
              expect(response.status).to eq(200)
            end
          end

          context 'acting user can’t act on discourse event' do
            let(:lurker) { Fabricate(:user) }

            before do
              sign_in(lurker)
            end

            it 'doesn’t destroy the invitee' do
              invitee = post_event_2.invitees.first
              delete "/discourse-post-event/events/#{post_event_2.id}/invitees/#{invitee.id}.json"
              expect(Invitee.where(id: invitee.id).length).to eq(1)
              expect(response.status).to eq(403)
            end
          end
        end

        context 'when changing status' do
          it 'sets tracking of the topic' do
            invitee = post_event_2.invitees.first

            expect(invitee.status).to eq(0)

            put "/discourse-post-event/events/#{post_event_2.id}/invitees/#{invitee.id}.json", params: {
              invitee: {
                status: 'interested'
              }
            }

            tu = TopicUser.get(invitee.event.post.topic, invitee.user)
            expect(tu.notification_level).to eq(TopicUser.notification_levels[:tracking])

            put "/discourse-post-event/events/#{post_event_2.id}/invitees/#{invitee.id}.json", params: {
              invitee: {
                status: 'going'
              }
            }

            tu = TopicUser.get(invitee.event.post.topic, invitee.user)
            expect(tu.notification_level).to eq(TopicUser.notification_levels[:watching])

            put "/discourse-post-event/events/#{post_event_2.id}/invitees/#{invitee.id}.json", params: {
              invitee: {
                status: 'not_going'
              }
            }

            tu = TopicUser.get(invitee.event.post.topic, invitee.user)
            expect(tu.notification_level).to eq(TopicUser.notification_levels[:regular])
          end
        end
      end

      context 'when an invitee doesn’t exist' do
        let(:post_event_2) { Fabricate(:event, post: post_1) }

        it 'creates an invitee' do
          post "/discourse-post-event/events/#{post_event_2.id}/invitees.json", params: {
            invitee: {
              user_id: user.id,
              status: 'not_going',
            }
          }

          expect(Invitee).to exist(
            user_id: user.id,
            status: 2,
          )
        end

        it 'sets tracking of the topic' do
          post "/discourse-post-event/events/#{post_event_2.id}/invitees.json", params: {
            invitee: {
              user_id: user.id,
              status: 'going',
            }
          }

          invitee = Invitee.find_by(user_id: user.id)

          tu = TopicUser.get(invitee.event.post.topic, user)
          expect(tu.notification_level).to eq(TopicUser.notification_levels[:watching])
        end

        context 'when the invitee is the event owner' do
          let(:post_event_2) { Fabricate(:event, post: post_1) }

          it 'creates an invitee' do
            expect(post_event_2.invitees.length).to eq(0)

            post "/discourse-post-event/events/#{post_event_2.id}/invitees.json", params: {
              invitee: {
                status: 'interested'
              }
            }

            post_event_2.reload

            invitee = post_event_2.invitees.first
            expect(invitee.status).to eq(1)
            expect(invitee.post_id).to eq(post_1.id)
          end
        end
      end
    end
  end
end
