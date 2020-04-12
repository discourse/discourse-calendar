# frozen_string_literal: true

require "rails_helper"

describe DiscoursePostEvent::EventParser do
  subject { DiscoursePostEvent::EventParser }

  it 'works with no event' do
    events = subject.extract_events('this could be a nice event')
    expect(events.length).to eq(0)
  end

  it 'finds one event' do
    events = subject.extract_events('[wrap=event start="foo" end="bar"]\n[/wrap]')
    expect(events.length).to eq(1)
  end

  it 'finds multiple events' do
    events = subject.extract_events('[wrap=event start="foo" end="bar"]\n[/wrap] baz [wrap=event start="foo" end="bar"]\n[/wrap]')
    expect(events.length).to eq(2)
  end

  it 'parses options' do
    events = subject.extract_events('[wrap=event start="foo" end="bar"]\n[/wrap]')
    expect(events[0][:start]).to eq("foo")
    expect(events[0][:end]).to eq("bar")
  end

  it 'works with escaped string' do
    events = subject.extract_events("I am going to get that fixed.\n\n[wrap=event start=\"bar\"]\n[/wrap]\n\n[wrap=event start=\"foo\"]\n[/wrap]")
    expect(events[0][:start]).to eq("bar")
    expect(events[1][:start]).to eq("foo")
  end

  it 'parses options where value has spaces' do
    events = subject.extract_events('[wrap=event start="foo" name="bar baz"]\n[/wrap]')
    expect(events[0][:name]).to eq("bar baz")
  end

  it 'doesn’t parse invalid options' do
    events = subject.extract_events("I am going to get that fixed.\n\n[wrap=event start=\"foo\" something=\"bar\"]\n[/wrap]")
    expect(events[0][:something]).to be(nil)

    events = subject.extract_events("I am going to get that fixed.\n\n[wrap=event something=\"bar\"]\n[/wrap]")
    expect(events).to eq([])
  end
end
