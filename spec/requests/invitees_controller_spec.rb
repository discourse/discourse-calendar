# frozen_string_literal: true

require 'rails_helper'
require_relative '../fabricators/post_event_fabricator'

module DiscourseCalendar
  describe InviteesController do
    fab!(:user) { Fabricate(:user, admin: true) }
    fab!(:topic) { Fabricate(:topic, user: user) }
    fab!(:post1) { Fabricate(:post, user: user, topic: topic) }

    before do
      SiteSetting.queue_jobs = false
      SiteSetting.post_event_enabled = true
      sign_in(user)
    end

    context 'when a post event exists' do
      context 'when an invitee exists' do
        fab!(:invitee1) { Fabricate(:user) }
        fab!(:post_event) {
          pe = Fabricate(:post_event, post: post1)
          pe.create_invitees([{
            user_id: invitee1.id,
            status: Invitee.statuses[:going]
          }])
          pe
        }

        it 'updates its status' do
          invitee = post_event.invitees.first

          expect(invitee.status).to eq(0)

          put "/discourse-calendar/invitees/#{invitee.id}.json", params: {
            invitee: {
              status: "interested"
            }
          }

          invitee.reload

          expect(invitee.status).to eq(1)
        end
      end

      context 'when an invitee doesn’t exist' do
        fab!(:post_event) { Fabricate(:post_event, post: post1) }

        it 'creates an invitee' do
          post "/discourse-calendar/invitees.json", params: {
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
      end
    end
  end
end
