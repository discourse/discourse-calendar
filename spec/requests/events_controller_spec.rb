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
        expect(sample_invitees.map { |i| i['user']['id'] }).to match_array(group.group_users.map { |gu| gu.user.id })
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
        expect(sample_invitees.length).to eq(0)
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
        expect(sample_invitees.map { |i| i['user']['username'] }).to match_array(group.group_users.map(&:user).map(&:username))
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
        expect(sample_invitees.count).to eq(0)
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

      context 'when an event exists' do
        let(:event) { Fabricate(:event, post: post1) }

        context 'when we update the event' do
          context 'when an url is defined' do
            it 'changes the url' do
              url = 'https://www.google.fr'

              put "/discourse-post-event/events/#{event.id}.json", params: {
                event: { url: url }
              }

              event.reload

              expect(event.url).to eq(url)
            end
          end

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
              expect(event.raw_invitees).to eq(['trust_level_0'])
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
              expect(event.raw_invitees).to eq(['trust_level_0'])
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

          context 'when doing csv bulk invite' do
            let(:valid_file) {
              file = Tempfile.new("valid.csv")
              file.write("bob,going\n")
              file.write("sam,interested\n")
              file.write("the_foo_bar_group,not_going\n")
              file.rewind
              file
            }

            let(:empty_file) {
              file = Tempfile.new("invalid.pdf")
              file.rewind
              file
            }

            context 'current user can manage the event' do
              context 'no file is given' do
                it 'returns an error' do
                  post "/discourse-post-event/events/#{event.id}/csv-bulk-invite.json"
                  expect(response.parsed_body['error_type']).to eq('invalid_parameters')
                end
              end

              context 'empty file is given' do
                it 'returns an error' do
                  post "/discourse-post-event/events/#{event.id}/csv-bulk-invite.json", { params: { file: fixture_file_upload(empty_file) } }
                  expect(response.status).to eq(422)
                end
              end

              context 'a valid file is given' do
                before do
                  Jobs.run_later!
                end

                it 'enqueues the job and returns 200' do
                  expect_enqueued_with(job: :discourse_post_event_bulk_invite, args: {
                    "event_id" => event.id,
                    "invitees" => [
                      { 'identifier' => 'bob', 'attendance' => 'going' },
                      { 'identifier' => 'sam', 'attendance' => 'interested' },
                      { 'identifier' => 'the_foo_bar_group', 'attendance' => 'not_going' }
                    ],
                    "current_user_id" => user.id
                  }) do
                    post "/discourse-post-event/events/#{event.id}/csv-bulk-invite.json", { params: { file: fixture_file_upload(valid_file) } }
                  end

                  expect(response.status).to eq(200)
                end
              end
            end

            context 'current user can’t manage the event' do
              let(:lurker) { Fabricate(:user) }

              before do
                sign_in(lurker)
              end

              it 'returns an error' do
                post "/discourse-post-event/events/#{event.id}/csv-bulk-invite.json"
                expect(response.status).to eq(403)
              end
            end
          end

          context 'when doing bulk invite' do
            context 'current user can manage the event' do
              context 'no invitees is given' do
                it 'returns an error' do
                  post "/discourse-post-event/events/#{event.id}/bulk-invite.json"
                  expect(response.parsed_body['error_type']).to eq('invalid_parameters')
                end
              end

              context 'empty invitees are given' do
                it 'returns an error' do
                  post "/discourse-post-event/events/#{event.id}/bulk-invite.json", { params: { invitees: [] } }
                  expect(response.status).to eq(400)
                end
              end

              context 'valid invitees are given' do
                before do
                  Jobs.run_later!
                end

                it 'enqueues the job and returns 200' do
                  expect_enqueued_with(job: :discourse_post_event_bulk_invite, args: {
                    "event_id" => event.id,
                    "invitees" => [
                      { 'identifier' => 'bob', 'attendance' => 'going' },
                      { 'identifier' => 'sam', 'attendance' => 'interested' },
                      { 'identifier' => 'the_foo_bar_group', 'attendance' => 'not_going' }
                    ],
                    "current_user_id" => user.id
                  }) do
                    post "/discourse-post-event/events/#{event.id}/bulk-invite.json", { params: { invitees: [
                      { 'identifier' => 'bob', 'attendance' => 'going' },
                      { 'identifier' => 'sam', 'attendance' => 'interested' },
                      { 'identifier' => 'the_foo_bar_group', 'attendance' => 'not_going' }
                    ] } }
                  end

                  expect(response.status).to eq(200)
                end
              end
            end

            context 'current user can’t manage the event' do
              let(:lurker) { Fabricate(:user) }

              before do
                sign_in(lurker)
              end

              it 'returns an error' do
                post "/discourse-post-event/events/#{event.id}/bulk-invite.json"
                expect(response.status).to eq(403)
              end
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

        context 'when watching user is not logged' do
          before do
            sign_out
          end

          context 'when topic is public' do
            it 'can see the event' do
              get "/discourse-post-event/events/#{event.id}.json"

              expect(response.status).to eq(200)
            end
          end

          context 'when topic is not public' do
            before do
              event.post.topic.convert_to_private_message(Discourse.system_user)
            end

            it 'can’t see the event' do
              get "/discourse-post-event/events/#{event.id}.json"

              expect(response.status).to eq(404)
            end
          end
        end
      end
    end
  end
end
