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
    let(:topic) { Fabricate(:topic, user: user) }
    let(:post1) { Fabricate(:post, user: user, topic: topic) }

    context 'when a post event exists' do
      context 'when an invitee exists' do
        let(:invitee1) { Fabricate(:user) }
        let(:post_event) {
          pe = Fabricate(:event, post: post1)
          pe.create_invitees([{
            user_id: invitee1.id,
            status: Invitee.statuses[:going]
          }])
          pe
        }

        it 'updates its status' do
          invitee = post_event.invitees.first

          expect(invitee.status).to eq(0)

          put "/discourse-post-event/invitees/#{invitee.id}.json", params: {
            invitee: {
              status: "interested"
            }
          }

          invitee.reload

          expect(invitee.status).to eq(1)
        end
      end

      context 'when an invitee doesn’t exist' do
        let(:post_event) { Fabricate(:event, post: post1) }

        it 'creates an invitee' do
          post "/discourse-post-event/invitees.json", params: {
            invitee: {
              user_id: user.id,
              post_id: post_event.id,
              status: "not_going",
            }
          }

          expect(Invitee).to exist(
            post_id: post_event.id,
            user_id: user.id,
            status: 2,
          )
        end

        context 'when the invitee is the event owner' do
          let(:post_event) { Fabricate(:event, post: post1) }

          it 'creates an invitee' do
            expect(post_event.invitees.length).to eq(0)

            put "/discourse-post-event/invitees/#{post1.user.id}.json", params: {
              invitee: {
                post_id: post1.id,
                status: "interested"
              }
            }

            post_event.reload

            invitee = post_event.invitees.first
            expect(invitee.status).to eq(1)
          end
        end
      end
    end
  end
end
