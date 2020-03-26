# frozen_string_literal: true

require "rails_helper"
require_relative '../fabricators/post_event_fabricator'

module DiscourseCalendar
  describe PostEventsController do
    fab!(:user) { Fabricate(:user) }
    fab!(:topic) { Fabricate(:topic, user: user) }
    fab!(:post1) { Fabricate(:post, user: user, topic: topic) }
    fab!(:invitee1) { Fabricate(:user) }
    fab!(:invitee2) { Fabricate(:user) }

    before do
      SiteSetting.queue_jobs = false
      SiteSetting.displayed_invitees_limit = 3
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

      it 'creates a post event' do
        post '/discourse-calendar/post-events.json', params: {
          post_event: {
            id: post1.id
          }
        }

        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json['post_event']['id']).to eq(post1.id)
        expect(PostEvent).to exist(id: post1.id)
      end

      it 'accepts user and group invitees' do
        invitees = [invitee1.username, group.name]

        post '/discourse-calendar/post-events.json', params: {
          post_event: {
            id: post1.id,
            raw_invitees: invitees,
            status: PostEvent.statuses[:private],
            display_invitees: PostEvent.display_invitees_options[:everyone]
          }
        }

        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        sample_invitees = json['post_event']['sample_invitees']
        expect(sample_invitees.map { |i| i['user']['id'] }).to match_array([user.id, invitee1.id, group.group_users.first.user.id])
        raw_invitees = json['post_event']['raw_invitees']
        expect(raw_invitees).to match_array(invitees)
      end

      it 'accepts one user invitee' do
        post '/discourse-calendar/post-events.json', params: {
          post_event: {
            id: post1.id,
            status: PostEvent.statuses[:private],
            raw_invitees: [invitee1.username],
          }
        }

        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        sample_invitees = json['post_event']['sample_invitees']
        expect(sample_invitees[0]['user']['username']).to eq(user.username)
        expect(sample_invitees[1]['user']['username']).to eq(invitee1.username)
      end

      it 'accepts one group invitee' do
        post '/discourse-calendar/post-events.json', params: {
          post_event: {
            id: post1.id,
            status: PostEvent.statuses[:private],
            raw_invitees: [group.name],
          }
        }

        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        sample_invitees = json['post_event']['sample_invitees']
        expect(sample_invitees.map { |i| i['user']['username'] }).to match_array([user.username] + group.group_users.map(&:user).map(&:username))
      end

      it 'accepts no invitee' do
        post '/discourse-calendar/post-events.json', params: {
          post_event: {
            id: post1.id,
            raw_invitees: [],
            status: PostEvent.statuses[:private],
            display_invitees: PostEvent.display_invitees_options[:everyone]
          }
        }

        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        sample_invitees = json['post_event']['sample_invitees']
        expect(sample_invitees.count).to eq(1)
        expect(sample_invitees[0]['user']['username']).to eq(user.username)
      end

      it 'limits displayed invitees' do
        post '/discourse-calendar/post-events.json', params: {
          post_event: {
            id: post1.id,
            status: PostEvent.statuses[:private],
            raw_invitees: [
              invitee1.username,
              invitee2.username,
              invitee3.username,
              invitee4.username,
              invitee5.username,
            ],
          }
        }

        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        sample_invitees = json['post_event']['sample_invitees']
        expect(sample_invitees.map { |i| i['user']['username'] }).to match_array([user.username, invitee1.username, invitee2.username])
      end

      context 'when a post_event exists' do
        fab!(:post_event) { Fabricate(:post_event, post: post1) }

        context 'when we update the post_event' do
          context 'when status changes from standalone to private' do
            it 'changes the status, raw_invitees and invitees' do
              post_event.update!(status: PostEvent.statuses[:standalone])

              put "/discourse-calendar/post-events/#{post_event.id}.json", params: {
                post_event: {
                  status: PostEvent.statuses[:private].to_s,
                  raw_invitees: [invitee1.username]
                }
              }

              post_event.reload

              expect(post_event.status).to eq(PostEvent.statuses[:private])
              expect(post_event.raw_invitees).to eq([invitee1.username])
              expect(post_event.invitees.pluck(:user_id)).to match_array([invitee1.id])
            end
          end

          context 'when status changes from standalone to public' do
            it 'changes the status' do
              post_event.update!(status: PostEvent.statuses[:standalone])

              put "/discourse-calendar/post-events/#{post_event.id}.json", params: {
                post_event: {
                  status: PostEvent.statuses[:public].to_s
                }
              }

              post_event.reload

              expect(post_event.status).to eq(PostEvent.statuses[:public])
              expect(post_event.raw_invitees).to eq([])
              expect(post_event.invitees).to eq([])
            end
          end

          context 'when status changes from private to standalone' do
            it 'changes the status' do
              post_event.update!(
                status: PostEvent.statuses[:private],
                raw_invitees: [invitee1.username]
              )
              post_event.fill_invitees!

              post_event.reload

              expect(post_event.invitees.pluck(:user_id)).to eq([invitee1.id])
              expect(post_event.raw_invitees).to eq([invitee1.username])

              put "/discourse-calendar/post-events/#{post_event.id}.json", params: {
                post_event: {
                  status: PostEvent.statuses[:standalone].to_s
                }
              }

              post_event.reload

              expect(post_event.status).to eq(PostEvent.statuses[:standalone])
              expect(post_event.raw_invitees).to eq([])
              expect(post_event.invitees).to eq([])
            end
          end

          context 'when status changes from private to public' do
            it 'changes the status, removes raw_invitees and keeps invitees' do
              post_event.update!(
                status: PostEvent.statuses[:private],
                raw_invitees: [invitee1.username]
              )
              post_event.fill_invitees!

              post_event.reload

              expect(post_event.invitees.pluck(:user_id)).to eq([invitee1.id])
              expect(post_event.raw_invitees).to eq([invitee1.username])

              put "/discourse-calendar/post-events/#{post_event.id}.json", params: {
                post_event: {
                  status: PostEvent.statuses[:public].to_s
                }
              }

              post_event.reload

              expect(post_event.status).to eq(PostEvent.statuses[:public])
              expect(post_event.raw_invitees).to eq([])
              expect(post_event.invitees.pluck(:user_id)).to eq([invitee1.id])
            end
          end

          context 'when status changes from public to private' do
            it 'changes the status, removes raw_invitees and keeps invitees' do
              post_event.update!(status: PostEvent.statuses[:public])
              post_event.create_invitees([
                { user_id: invitee1.id },
                { user_id: invitee2.id },
              ])
              post_event.reload

              expect(post_event.invitees.pluck(:user_id)).to match_array([invitee1.id, invitee2.id])
              expect(post_event.raw_invitees).to eq(nil)

              put "/discourse-calendar/post-events/#{post_event.id}.json", params: {
                post_event: {
                  status: PostEvent.statuses[:private].to_s,
                  raw_invitees: [invitee1.username]
                }
              }

              post_event.reload

              expect(post_event.status).to eq(PostEvent.statuses[:private])
              expect(post_event.raw_invitees).to eq([invitee1.username])
              expect(post_event.invitees.pluck(:user_id)).to eq([invitee1.id])
            end
          end

          context 'when status changes from public to standalone' do
            it 'changes the status, removes invitees' do
              post_event.update!(
                status: PostEvent.statuses[:public]
              )
              post_event.create_invitees([ { user_id: invitee1.id } ])
              post_event.reload

              expect(post_event.invitees.pluck(:user_id)).to eq([invitee1.id])
              expect(post_event.raw_invitees).to eq(nil)

              put "/discourse-calendar/post-events/#{post_event.id}.json", params: {
                post_event: {
                  status: PostEvent.statuses[:standalone].to_s
                }
              }

              post_event.reload

              expect(post_event.status).to eq(PostEvent.statuses[:standalone])
              expect(post_event.raw_invitees).to eq([])
              expect(post_event.invitees).to eq([])
            end
          end
        end

        context 'acting user has created the post_event' do
          it 'destroys a post_event' do
            expect(post_event.persisted?).to be(true)

            messages = MessageBus.track_publish do
              delete "/discourse-calendar/post-events/#{post_event.id}.json"
            end
            expect(messages.count).to eq(1)
            message = messages.first
            expect(message.channel).to eq("/post-events/#{post_event.post.topic_id}")
            expect(message.data[:id]).to eq(post_event.id)
            expect(response.status).to eq(200)
            expect(PostEvent).to_not exist(id: post_event.id)
          end
        end

        context 'acting user has not created the post_event' do
          fab!(:lurker) { Fabricate(:user) }

          before do
            sign_in(lurker)
          end

          it 'doesn’t destroy the post_event' do
            expect(post_event.persisted?).to be(true)
            delete "/discourse-calendar/post-events/#{post_event.id}.json"
            expect(response.status).to eq(403)
            expect(PostEvent).to exist(id: post_event.id)
          end

          it 'doesn’t update the post_event' do
            put "/discourse-calendar/post-events/#{post_event.id}.json", params: {
              post_event: {
                status: PostEvent.statuses[:public],
              }
            }

            expect(response.status).to eq(403)
          end
        end
      end
    end
  end
end
