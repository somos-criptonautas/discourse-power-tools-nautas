# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Participation badges in Power Tools Nautas" do
  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.dumbcourse_enabled = true
    DiscourseJtechBadges.seed!
    DiscourseJtechBadges::SWITCHES.each_key { |set| DiscourseJtechBadges.refresh!(set) }
  end

  it "keeps them off until jtech_badges_enabled is on" do
    expect(Badge.find_by!(name: "Flip Phone").enabled).to eq(false)

    SiteSetting.jtech_badges_enabled = true
    expect(Badge.find_by!(name: "Flip Phone").reload.enabled).to eq(true)
  end
end
