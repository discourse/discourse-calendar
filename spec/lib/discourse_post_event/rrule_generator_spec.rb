# frozen_string_literal: true

require 'rails_helper'

describe RRuleGenerator do
  let(:time) { Time.now }

  before { freeze_time Time.utc(2020, 8, 12, 16, 32) }

  context 'every week' do
    let(:sample_rrule) { 'FREQ=WEEKLY;BYDAY=MO' }

    context 'a rule and time are given' do
      it 'generates the rule' do
        rrule = RRuleGenerator.generate(sample_rrule, time)
        expect(rrule.to_s).to eq('2020-08-17 16:32:00 UTC')
      end

      context 'the given time is a valid next' do
        let(:time) { Time.utc(2020, 8, 10, 16, 32) }

        it 'returns the next valid after given time' do
          rrule = RRuleGenerator.generate(sample_rrule, time)
          expect(rrule.to_s).to eq('2020-08-17 16:32:00 UTC')
        end
      end
    end
  end

  context 'every day' do
    let(:sample_rrule) { 'FREQ=DAILY' }

    context 'a rule and time are given' do
      it 'generates the rule' do
        rrule = RRuleGenerator.generate(sample_rrule, time)
        expect(rrule.to_s).to eq('2020-08-13 16:32:00 UTC')
      end

      context 'the given time is a valid next' do
        let(:time) { Time.utc(2020, 8, 10, 16, 32) }

        it 'returns the next valid after given time and in the future' do
          rrule = RRuleGenerator.generate(sample_rrule, time)
          expect(rrule.to_s).to eq('2020-08-12 16:32:00 UTC')
        end
      end
    end
  end
end
