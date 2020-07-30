# frozen_string_literal: true

require 'rails_helper'

describe PrettyText do
  before do
    freeze_time
  end

  describe 'An event is displayed in an email' do
    before do
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
    end

    let(:user) { Fabricate(:user, admin: true) }

    context 'The event has no name' do
      let(:post_1) {
        create_post(
          user: user,
          raw: <<~TXT.strip
            [event start="2018-05-08"]
            [/event]
          TXT
        )
      }

      it 'displays the topic title' do
        cooked = PrettyText.cook(post_1.raw)

        expect(PrettyText.format_for_email(cooked, post_1)).to match_html(<<~HTML)
          <div style='border:1px solid #dedede'>
            <p><a href="#{Discourse.base_url}#{post_1.url}">#{post_1.topic.title}</a></p>
            <p>2018-05-08 (UTC)</p>
          </div>
        HTML
      end
    end

    context 'The event has a name' do
      let(:post_1) {
        create_post(
          user: user,
          raw: <<~TXT.strip
            [event start="2018-05-08" name="Pancakes event"]
            [/event]
          TXT
        )
      }

      it 'displays the event name' do
        cooked = PrettyText.cook(post_1.raw)

        expect(PrettyText.format_for_email(cooked, post_1)).to match_html(<<~HTML)
          <div style='border:1px solid #dedede'>
            <p><a href="#{Discourse.base_url}#{post_1.url}">Pancakes event</a></p>
            <p>2018-05-08 (UTC)</p>
          </div>
        HTML
      end
    end

    context 'The event has an end date' do
      let(:post_1) {
        create_post(
          user: user,
          raw: <<~TXT.strip
            [event start="2018-05-08" end="2018-06-22"]
            [/event]
          TXT
        )
      }

      it 'displays the end date' do
        cooked = PrettyText.cook(post_1.raw)

        expect(PrettyText.format_for_email(cooked, post_1)).to match_html(<<~HTML)
          <div style='border:1px solid #dedede'>
            <p><a href="#{Discourse.base_url}#{post_1.url}">#{post_1.topic.title}</a></p>
            <p>2018-05-08 (UTC) → 2018-06-22 (UTC)</p>
          </div>
        HTML
      end
    end
  end
end
