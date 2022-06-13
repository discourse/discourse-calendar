# frozen_string_literal: true

require "rails_helper"

def build_post(user, raw)
  Post.new(user: user, raw: raw)
end

describe DiscoursePostEvent::EventParser do
  subject { DiscoursePostEvent::EventParser }

  let(:user) { Fabricate(:user) }

  it 'works with no event' do
    events = subject.extract_events(build_post(user, 'this could be a nice event'))
    expect(events.length).to eq(0)
  end

  it 'finds one event' do
    events = subject.extract_events(build_post(user, '[event start="foo" end="bar"]\n[/event]'))
    expect(events.length).to eq(1)
  end

  it 'finds multiple events' do
    post_event = build_post user, <<~TXT
      [event start="2020"]
      [/event]

      [event start="2021"]
      [/event]
    TXT

    events = subject.extract_events(post_event)
    expect(events.length).to eq(2)
  end

  it 'parses options' do
    events = subject.extract_events(build_post(user, '[event start="foo" end="bar"]\n[/event]'))
    expect(events[0][:start]).to eq("foo")
    expect(events[0][:end]).to eq("bar")
  end

  it 'works with escaped string' do
    events = subject.extract_events(build_post(user, "I am going to get that fixed.\n\n[event start=\"bar\"]\n[/event]"))
    expect(events[0][:start]).to eq("bar")
  end

  it 'parses options where value has spaces' do
    events = subject.extract_events(build_post(user, '[event start="foo" name="bar baz"]\n[/event]'))
    expect(events[0][:name]).to eq("bar baz")
  end

  it 'doesn’t parse invalid options' do
    events = subject.extract_events(build_post(user, "I am going to get that fixed.\n\n[event start=\"foo\" something=\"bar\"]\n[/event]"))
    expect(events[0][:something]).to be(nil)

    events = subject.extract_events(build_post(user, "I am going to get that fixed.\n\n[event something=\"bar\"]\n[/event]"))
    expect(events).to eq([])
  end

  it 'doesn’t parse an event in codeblock' do
    post_event = build_post user, <<-TXT
      Example event:
      ```
      [event start=\"bar\"]\n[/event]
      ```
    TXT

    events = subject.extract_events(post_event)

    expect(events).to eq([])
  end

  it 'doesn’t parse in blockquote' do
    post_event = build_post user, <<-TXT
      [event start="2020"][/event]
    TXT

    events = subject.extract_events(post_event)
    expect(events).to eq([])
  end

  it 'doesn’t escape event name' do
    events = subject.extract_events(build_post(user, '[event start="foo" name="bar <script> baz"]\n[/event]'))
    expect(events[0][:name]).to eq("bar <script> baz")
  end

  context 'with custom fields' do
    before do
      SiteSetting.discourse_post_event_allowed_custom_fields = 'foo-bar|bar'
    end

    it 'parses allowed custom fields' do
      post_event = build_post user, <<~TXT
        [event start="2020" fooBar="1" bar="2"]
        [/event]
      TXT

      events = subject.extract_events(post_event)
      expect(events[0][:"foo-bar"]).to eq("1")
      expect(events[0][:"bar"]).to eq("2")
    end

    it 'doesn’t parse not allowed custom fields' do
      post_event = build_post user, <<~TXT
        [event start="2020" baz="1"]
        [/event]
      TXT

      events = subject.extract_events(post_event)
      expect(events[0][:"baz"]).to eq(nil)
    end
  end
end
