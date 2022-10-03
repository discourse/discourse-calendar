# frozen_string_literal: true
require "rails_helper"

describe DiscoursePostEvent::EventSerializer do
  Event ||= DiscoursePostEvent::Event
  Invitee ||= DiscoursePostEvent::Invitee
  EventSerializer ||= DiscoursePostEvent::EventSerializer

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  let(:post_1) { Fabricate(:post) }
  let(:event_1) { Fabricate(:event, post: post_1, status: Event.statuses[:private]) }
  let(:invitee_1) { Fabricate(:user) }
  let(:invitee_2) { Fabricate(:user) }
  let(:group_1) {
    Fabricate(:group).tap do |g|
      g.add(invitee_1)
      g.add(invitee_2)
      g.save!
    end
  }

  context 'with a private event' do
    context 'when some invited users have not rsvp-ed yet' do
      before do
        event_1.update_with_params!(raw_invitees: [group_1.name])
        Invitee.create_attendance!(invitee_1.id, event_1.id, :going)
        event_1.reload
      end

      it 'returns the correct stats' do
        json = EventSerializer.new(event_1, scope: Guardian.new).as_json
        expect(json[:event][:stats]).to eq(going: 1, interested: 0, invited: 2, not_going: 0)
      end
    end
  end
end
