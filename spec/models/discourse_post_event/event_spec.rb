# frozen_string_literal: true

require 'rails_helper'
require_relative '../../fabricators/event_fabricator'

describe DiscoursePostEvent::Event do
  Event ||= DiscoursePostEvent::Event
  Field ||= DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT

  before do
    freeze_time DateTime.parse('2020-04-24 14:10')
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  describe 'topic custom fields callback' do
    let(:user) { Fabricate(:user, admin: true) }
    let(:topic) { Fabricate(:topic, user: user) }
    let!(:first_post) { Fabricate(:post, topic: topic) }
    let(:second_post) { Fabricate(:post, topic: topic) }
    let!(:starts_at) { '2020-04-24 14:15:00' }
    let!(:alt_starts_at) { '2020-04-25 14:15:25' }

    describe '#after_commit[:create, :update]' do
      context 'a post event has been created' do
        context 'the associated post is the OP' do
          it 'sets the topic custom field' do
            expect(first_post.is_first_post?).to be(true)
            expect(first_post.topic.custom_fields).to be_blank

            Event.create!(id: first_post.id, starts_at: starts_at)
            first_post.topic.reload

            expect(first_post.topic.custom_fields[Field]).to eq(starts_at)
          end
        end

        context 'the associated post is not the OP' do
          it 'doesn’t set the topic custom field' do
            expect(second_post.is_first_post?).to be(false)
            expect(second_post.topic.custom_fields).to be_blank

            Event.create!(id: second_post.id, starts_at: starts_at)
            second_post.topic.reload

            expect(second_post.topic.custom_fields).to be_blank
          end
        end

        context 'setting dates enqueues future jobs at date' do
          before do
            Jobs.run_later!
          end

          context 'starts_at' do
            context 'is after current time' do
              it 'queues a future discourse event trigger' do
                expect_enqueued_with(job: :discourse_post_event_event_started, args: {
                  "event_id" => first_post.id
                }) do
                  Event.create!(id: first_post.id, starts_at: starts_at)
                end
              end
            end

            context 'is before current time' do
              it 'doesn’t queues a future discourse event trigger' do
                expect {
                  Event.create!(id: first_post.id, starts_at: Time.now - 1.day)
                }.to change {
                  Jobs::DiscoursePostEventEventStarted.jobs.count +
                  Jobs::DiscoursePostEventEventWillStart.jobs.count
                }.by(0)
              end
            end

            context 'an event started job was already scheduled' do
              it 'queues a future discourse event trigger' do
                Jobs
                  .expects(:cancel_scheduled_job)
                  .with(:discourse_post_event_event_ended, event_id: first_post.id)
                  .never

                Jobs
                  .expects(:cancel_scheduled_job)
                  .with(:discourse_post_event_event_started, event_id: first_post.id)
                  .at_least_once

                Jobs
                  .expects(:cancel_scheduled_job)
                  .with(:discourse_post_event_event_will_start, event_id: first_post.id)
                  .at_least_once

                Event.create!(id: first_post.id, starts_at: starts_at)

                expect(Jobs::DiscoursePostEventEventStarted.jobs.count).to eq(1)
                expect(Jobs::DiscoursePostEventEventWillStart.jobs.count).to eq(0)

                Event.find(first_post.id).update!(starts_at: Time.now + 2.hours)

                expect(Jobs::DiscoursePostEventEventStarted.jobs.count).to eq(2)
                expect(Jobs::DiscoursePostEventEventWillStart.jobs.count).to eq(1)
              end
            end
          end

          context 'ends_at' do
            context 'is after current time' do
              it 'queues a future discourse event trigger' do
                expect_enqueued_with(job: :discourse_post_event_event_ended, args: {
                  "event_id" => first_post.id
                }) do
                  Event.create!(id: first_post.id, starts_at: Time.now - 1.day, ends_at: Time.now + 12.hours)
                end
              end
            end

            context 'is before current time' do
              it 'doesn’t queue a future discourse event trigger' do
                expect {
                  Event.create!(id: first_post.id, starts_at: Time.now - 1.day, ends_at: Time.now - 12.hours)
                }.to change {
                  Jobs::DiscoursePostEventEventEnded.jobs.count
                }.by(0)
              end
            end

            context 'an event ended job was already scheduled' do
              it 'queues a future discourse event trigger' do
                Jobs
                  .expects(:cancel_scheduled_job)
                  .with(:discourse_post_event_event_ended, event_id: first_post.id)
                  .at_least_once

                Jobs
                  .expects(:cancel_scheduled_job)
                  .with(:discourse_post_event_event_started, event_id: first_post.id)
                  .at_least_once

                Jobs
                  .expects(:cancel_scheduled_job)
                  .with(:discourse_post_event_event_will_start, event_id: first_post.id)
                  .at_least_once

                Event.create!(id: first_post.id, starts_at: Time.now - 1.day, ends_at: Time.now + 12.hours)

                expect(Jobs::DiscoursePostEventEventEnded.jobs.count).to eq(1)

                Event.find(first_post.id).update!(starts_at: Time.now - 1.day, ends_at: Time.now + 13.hours)

                expect(Jobs::DiscoursePostEventEventEnded.jobs.count).to eq(2)
              end
            end
          end
        end
      end

      context 'a post event has been updated' do
        context 'the associated post is the OP' do
          let!(:post_event) { Fabricate(:event, post: first_post, starts_at: starts_at) }

          it 'sets the topic custom field' do
            expect(first_post.is_first_post?).to be(true)
            expect(first_post.topic.custom_fields[Field]).to eq(starts_at)

            post_event.update!(starts_at: alt_starts_at)
            first_post.topic.reload

            expect(first_post.topic.custom_fields[Field]).to eq(alt_starts_at)
          end
        end

        context 'the associated post is not the OP' do
          let(:post_event) { Fabricate(:event, post: second_post, starts_at: starts_at) }

          it 'doesn’t set the topic custom field' do
            expect(second_post.is_first_post?).to be(false)
            expect(second_post.topic.custom_fields[Field]).to be_blank

            post_event.update!(starts_at: alt_starts_at)
            second_post.topic.reload

            expect(second_post.topic.custom_fields[Field]).to be_blank
          end
        end
      end
    end

    describe '#after_commit[:destroy]' do
      context 'a post event has been destroyed' do
        context 'the associated post is the OP' do
          let!(:post_event) { Fabricate(:event, post: first_post, starts_at: starts_at) }

          it 'sets the topic custom field' do
            expect(first_post.is_first_post?).to be(true)
            expect(first_post.topic.custom_fields[Field]).to eq(starts_at)

            post_event.destroy!
            first_post.topic.reload

            expect(first_post.topic.custom_fields[Field]).to be_blank
          end
        end

        context 'the associated post is not the OP' do
          let!(:first_post_event) { Fabricate(:event, post: first_post, starts_at: starts_at) }
          let!(:second_post_event) { Fabricate(:event, post: second_post, starts_at: starts_at) }

          it 'doesn’t change the topic custom field' do
            expect(first_post.is_first_post?).to be(true)
            expect(second_post.topic.custom_fields[Field]).to eq(starts_at)
            expect(second_post.is_first_post?).to be(false)

            second_post_event.destroy!
            second_post.topic.reload

            expect(second_post.topic.custom_fields[Field]).to eq(starts_at)
          end
        end
      end
    end
  end

  describe '#is_expired?' do
    context 'has ends_at' do
      context '&& starts_at < current date' do
        context '&& ends_at < current date' do
          it 'is expired' do
            post_event = Event.new(
              starts_at: DateTime.parse('2020-04-22 14:05'),
              ends_at: DateTime.parse('2020-04-23 14:05'),
            )

            expect(post_event.is_expired?).to be(true)
          end
        end

        context '&& ends_at > current date' do
          it 'is not expired' do
            post_event = Event.new(
              starts_at: DateTime.parse('2020-04-24 14:15'),
              ends_at: DateTime.parse('2020-04-25 11:05'),
            )

            expect(post_event.is_expired?).to be(false)
          end
        end

        context '&& ends_at < current date' do
          it 'is expired' do
            post_event = Event.new(
              starts_at: DateTime.parse('2020-04-22 14:15'),
              ends_at: DateTime.parse('2020-04-23 11:05'),
            )

            expect(post_event.is_expired?).to be(true)
          end
        end
      end

      context '&& starts_at > current date' do
        it 'is not expired' do
          post_event = Event.new(
            starts_at: DateTime.parse('2020-04-25 14:05'),
            ends_at: DateTime.parse('2020-04-26 14:05'),
          )

          expect(post_event.is_expired?).to be(false)
        end
      end
    end

    context 'has not ends_at date' do
      context '&& starts_at < current date' do
        it 'is expired' do
          post_event = Event.new(
            starts_at: DateTime.parse('2020-04-24 14:05')
          )

          expect(post_event.is_expired?).to be(true)
        end
      end

      context '&& starts_at == current date' do
        it 'is expired' do
          post_event = Event.new(
            starts_at: DateTime.parse('2020-04-24 14:10')
          )

          expect(post_event.is_expired?).to be(false)
        end
      end

      context '&& starts_at > current date' do
        it 'is not expired' do
          post_event = Event.new(
            starts_at: DateTime.parse('2020-04-24 14:15')
          )

          expect(post_event.is_expired?).to be(false)
        end
      end
    end
  end

  context 'reminders callbacks' do
    let!(:post_1) { Fabricate(:post) }
    let!(:event_1) { Fabricate(:event, post: post_1) }

    before do
      freeze_time
    end

    it 'does nothing with no reminders' do
      Jobs.expects(:cancel_scheduled_job).with(:discourse_post_event_send_reminder, event_id: event_1.id).never
      event_1.save!
    end

    it 'creates jobs with reminders' do
      Jobs.expects(:cancel_scheduled_job).with(:discourse_post_event_send_reminder, event_id: event_1.id, reminder: '1.hours').once
      Jobs.expects(:cancel_scheduled_job).with(:discourse_post_event_send_reminder, event_id: event_1.id, reminder: '-2.days').once
      Jobs.expects(:enqueue_at).with(event_1.starts_at - 1.hour, :discourse_post_event_send_reminder, event_id: event_1.id, reminder: '1.hours').once
      Jobs.expects(:enqueue_at).with(event_1.starts_at + 2.days, :discourse_post_event_send_reminder, event_id: event_1.id, reminder: '-2.days').once

      event_1.update!(reminders: '1.hours,-2.days')
    end

    context 'reminder is after current time' do
      before do
        event_1.update!(starts_at: 30.minutes.from_now)
      end

      it 'doesn’t create job' do
        Jobs.expects(:cancel_scheduled_job).with(:discourse_post_event_send_reminder, event_id: event_1.id, reminder: '1.hours').once
        Jobs.expects(:enqueue_at).with(event_1.starts_at - 1.hour, :discourse_post_event_send_reminder, event_id: event_1.id, reminder: '1.hours').never

        event_1.update!(reminders: '1.hours')
      end
    end

    context 'starts at is changed' do
      context 'event has reminders' do
        before do
          event_1.update!(reminders: '1.hours')
        end

        it 'creates jobs with reminders' do
          Jobs.expects(:cancel_scheduled_job).with(:discourse_post_event_event_started, event_id: event_1.id).once
          Jobs.expects(:cancel_scheduled_job).with(:discourse_post_event_event_will_start, event_id: event_1.id).once
          Jobs.expects(:cancel_scheduled_job).with(:discourse_post_event_send_reminder, event_id: event_1.id, reminder: '1.hours').once
          Jobs.expects(:enqueue_at).with(2.hours.from_now - 1.hour, :discourse_post_event_send_reminder, event_id: event_1.id, reminder: '1.hours').once
          Jobs.expects(:enqueue_at).with(2.hours.from_now - 1.hour, :discourse_post_event_event_will_start, event_id: event_1.id).once
          Jobs.expects(:enqueue_at).with(2.hours.from_now, :discourse_post_event_event_started, event_id: event_1.id).once

          event_1.update!(starts_at: 2.hours.from_now)
        end
      end
    end
  end
end
