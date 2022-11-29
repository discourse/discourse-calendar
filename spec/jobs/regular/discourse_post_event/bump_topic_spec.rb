
# frozen_string_literal: true

require 'rails_helper'

describe Jobs::DiscoursePostEventBumpTopic do

  let(:admin_1) { Fabricate(:user, admin: true) }
  let(:topic_1) { Fabricate(:topic, user: admin_1) }

  before do
    freeze_time DateTime.parse('2019-11-10 12:00')

    Jobs.run_immediately!

    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  describe '#execute' do
    context 'when params are present' do
      it 'creates an auto-bump topic timer' do
        freeze_time
        subject.execute(topic_id: topic_1.id, date: '2019-12-10 5:00')

        timer = TopicTimer.find_by(topic: topic_1)
        expect(timer.status_type).to eq(TopicTimer.types[:bump])
        expect(timer.execute_at).to eq_time(Time.zone.local(2019, 12, 10, 5, 0))
      end
    end

    context 'when the topic_id param is missing' do
      it 'ddoes not throw an error if the date param is present' do
        expect {
          subject.execute(date: '2019-12-10 5:00')
        }.not_to raise_error
      end
      it 'does not throw an error if the date param is missing' do
        expect { subject.execute({}) }.not_to raise_error
      end
    end

    context 'when the date param is missing' do
      before do
        Fabricate(:topic_timer,
        status_type: TopicTimer.types[:bump],
        execute_at: 3.days.from_now,
        topic: topic_1,
        user: admin_1
       )
      end

      it 'deletes the timer if type is bump' do
        expect do
          subject.execute(topic_id: topic_1.id)
        end.to change { TopicTimer.exists?(topic: topic_1) }.from(true).to(false)
      end
    end

    context 'when the date param is missing' do
      before do
        Fabricate(:topic_timer,
        status_type: TopicTimer.types[:close],
        execute_at: 2.days.from_now,
        topic: topic_1,
        user: admin_1
       )
      end

      it 'does not delete the timer if type is not bump' do
        subject.execute(topic_id: topic_1.id)

        timer = TopicTimer.find_by(topic: topic_1)
        expect(timer.status_type).to eq(TopicTimer.types[:close])
        expect(timer.execute_at).to eq_time(2.days.from_now)
      end
    end
  end
end
