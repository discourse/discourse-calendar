# frozen_string_literal: true

require 'rails_helper'
require_relative '../fabricators/post_event_fabricator'

describe DiscourseCalendar::PostEvent do
  PostEvent ||= DiscourseCalendar::PostEvent

  before do
    freeze_time DateTime.parse('2020-04-24 14:10')
    Jobs.run_immediately!
    SiteSetting.post_event_enabled = true
  end

  describe '#is_expired?' do
    context 'has ends_at' do
      context '&& starts_at < current date' do
        context '&& ends_at < current date' do
          it 'is expired' do
            post_event = PostEvent.new(
              starts_at: DateTime.parse('2020-04-22 14:05'),
              ends_at: DateTime.parse('2020-04-23 14:05'),
            )

            expect(post_event.is_expired?).to be(true)
          end
        end

        context '&& ends_at > current date' do
          it 'is not expired' do
            post_event = PostEvent.new(
              starts_at: DateTime.parse('2020-04-24 14:15'),
              ends_at: DateTime.parse('2020-04-25 11:05'),
            )

            expect(post_event.is_expired?).to be(false)
          end
        end

        context '&& ends_at < current date' do
          it 'is expired' do
            post_event = PostEvent.new(
              starts_at: DateTime.parse('2020-04-22 14:15'),
              ends_at: DateTime.parse('2020-04-23 11:05'),
            )

            expect(post_event.is_expired?).to be(true)
          end
        end
      end

      context '&& starts_at > current date' do
        it 'is not expired' do
          post_event = PostEvent.new(
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
          post_event = PostEvent.new(
            starts_at: DateTime.parse('2020-04-24 14:05')
          )

          expect(post_event.is_expired?).to be(true)
        end
      end

      context '&& starts_at == current date' do
        it 'is expired' do
          post_event = PostEvent.new(
            starts_at: DateTime.parse('2020-04-24 14:10')
          )

          expect(post_event.is_expired?).to be(false)
        end
      end

      context '&& starts_at > current date' do
        it 'is not expired' do
          post_event = PostEvent.new(
            starts_at: DateTime.parse('2020-04-24 14:15')
          )

          expect(post_event.is_expired?).to be(false)
        end
      end
    end
  end
end
