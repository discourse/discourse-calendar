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
    events = subject.extract_events(build_post(user, '[wrap=event start="foo" end="bar"]\n[/wrap]'))
    expect(events.length).to eq(1)
  end

  it 'finds multiple events' do
    post_event = build_post user, <<-TXT
[wrap=event start="2020"][/wrap]

[wrap=event start="2021"][/wrap]
    TXT

    events = subject.extract_events(post_event)
    expect(events.length).to eq(2)
  end

  it 'parses options' do
    events = subject.extract_events(build_post(user, '[wrap=event start="foo" end="bar"]\n[/wrap]'))
    expect(events[0][:start]).to eq("foo")
    expect(events[0][:end]).to eq("bar")
  end

  it 'works with escaped string' do
    events = subject.extract_events(build_post(user, "I am going to get that fixed.\n\n[wrap=event start=\"bar\"]\n[/wrap]"))
    expect(events[0][:start]).to eq("bar")
  end

  it 'parses options where value has spaces' do
    events = subject.extract_events(build_post(user, '[wrap=event start="foo" name="bar baz"]\n[/wrap]'))
    expect(events[0][:name]).to eq("bar baz")
  end

  it 'doesn’t parse invalid options' do
    events = subject.extract_events(build_post(user, "I am going to get that fixed.\n\n[wrap=event start=\"foo\" something=\"bar\"]\n[/wrap]"))
    expect(events[0][:something]).to be(nil)

    events = subject.extract_events(build_post(user, "I am going to get that fixed.\n\n[wrap=event something=\"bar\"]\n[/wrap]"))
    expect(events).to eq([])
  end

  it 'doesn’t parse an event in codeblock' do
    post_event = build_post user, <<-TXT
      Example event:
      ```
      [wrap=event start=\"bar\"]\n[/wrap]
      ```
    TXT

    events = subject.extract_events(post_event)

    expect(events).to eq([])
  end

  it 'doesn’t parse in blockquote' do
    post_event = build_post user, <<-TXT
      [wrap=event start="2020"][/wrap]
    TXT

    events = subject.extract_events(post_event)
    expect(events).to eq([])
  end
end
