# frozen_string_literal: true

require 'rails_helper'

describe 'currently_away report' do
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:group_1) { Fabricate(:group) }

  before do
    group_1.add(user_1)

    DiscourseCalendar.users_on_holiday = [user_1.username]
  end

  it 'generates a correct report' do
    report = Report.find('currently_away', filters: { group: group_1.id })

    expect(report.data).to contain_exactly({ username: user_1.username })
    expect(report.total).to eq(1)
  end
end
