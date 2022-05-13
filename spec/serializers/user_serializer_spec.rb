# frozen_string_literal: true

require "rails_helper"

describe UserSerializer do
  fab!(:user) { Fabricate(:user) }

  subject { described_class.new(user, scope: guardian).as_json }

  before do
    SiteSetting.calendar_enabled = true
    user.upsert_custom_fields(DiscourseCalendar::REGION_CUSTOM_FIELD => "uk")
  end

  context "as user" do
    fab!(:guardian) { Fabricate(:user).guardian }

    it "does not return user region" do
      expect(subject[:user][:custom_fields]).to be_blank
    end
  end

  context "as current user" do
    fab!(:guardian) { user.guardian }

    it "returns user region" do
      expect(subject[:user][:custom_fields]).to eq(DiscourseCalendar::REGION_CUSTOM_FIELD => "uk")
    end
  end

  context "as staff" do
    fab!(:guardian) { Fabricate(:admin).guardian }

    it "returns user region" do
      expect(subject[:user][:custom_fields]).to eq(DiscourseCalendar::REGION_CUSTOM_FIELD => "uk")
    end
  end
end
