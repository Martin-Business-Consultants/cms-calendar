# frozen_string_literal: true

require "rails_helper"
require_relative "../support/calendar_helpers"

RSpec.describe Calendar::Ideas do
  before do
    switch_plugin :calendar, on: true
    switch_plugin :market, on: true
  end

  around { |example| travel_to(Time.zone.local(2026, 10, 13, 9)) { example.run } }

  def snapshot(kind, data) = Market::SearchSnapshot.create!(domain: "acme.example", kind: kind, taken_at: Time.current, data: data)

  it "dates a search's season two months before its peak, soon when that's passed, and not at all when it's far off" do
    expect(described_class.publish_on(2)).to eq(Date.new(2026, 12, 1))
    expect(described_class.publish_on(11)).to eq(Date.new(2026, 10, 14))
    expect(described_class.publish_on(6)).to be_nil
    expect(described_class.publish_on(nil)).to be_nil
  end

  it "offers Market's searches worth writing about, those coming into season first and dated, and doesn't offer one twice" do
    snapshot("content_ideas", {"ideas" => [
      {"keyword" => "how much does a plumber cost", "volume" => 1300, "difficulty" => 18, "question" => true},
      {"keyword" => "frozen pipes", "volume" => 900, "difficulty" => 30, "peak" => {"month" => 1, "lift" => 220}}
    ]})
    snapshot("keyword_facts", {"keywords" => {"furnace repair" => {"volume" => 2400, "months" => (1..12).to_h { ["2026-#{it.to_s.rjust(2, "0")}", (it == 12) ? 900 : 200] }}}})

    ideas = described_class.new.all
    expect(ideas.map(&:source)).to eq(%w[market:season:furnace-repair market:idea:frozen-pipes market:idea:how-much-does-a-plumber-cost])
    furnace, frozen, cost = ideas
    expect(frozen).to have_attributes(title: "Write about “frozen pipes”", on: Date.new(2026, 11, 2), timely: true, origin: "Market · coming into season")
    expect(frozen.facts).to eq("900 searches a month · difficulty 30 · peaks in January")
    expect(furnace).to have_attributes(title: "Get ready for “furnace repair” season", on: Date.new(2026, 10, 14))
    expect(cost).to have_attributes(on: nil, timely: false)
    expect(cost.detail).to include("FAQ")

    Calendar::Item.create!(title: "Frozen pipes", kind: "post", state: "idea", source: "market:idea:frozen-pipes")
    expect(described_class.new.all.map(&:source)).not_to include("market:idea:frozen-pipes")
    expect(Calendar::Context.business).to include("Coming into season", "furnace repair", "Searches worth writing about", "how much does a plumber cost")
  end
end
