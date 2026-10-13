# frozen_string_literal: true

require "rails_helper"
require_relative "../support/calendar_helpers"

RSpec.describe "Calendar and the AI" do
  before do
    switch_plugin :calendar, on: true
    skip "the AI plugin isn't installed" unless defined?(::Ai::Settings)
    switch_plugin :ai, on: true
    Ai::Settings.update("provider" => "opencode", "api_key" => "zen-key")
  end

  it "drafts each channel's post in its own shape, from the item and the business" do
    facebook = channel("facebook")
    x = channel("x")
    item = Calendar::Item.create!(title: "Same-day repairs", body: "Leaks fixed today", state: "idea")
    item.assign_channels([facebook.id, x.id])
    item.save!
    asked = nil
    allow(Ai).to receive(:structured) { |**request| asked = request; {"body" => "Leaks fixed the day you call.", "facebook" => "Leak? We'll be there today.", "x" => "Leak? Same day. " + ("!" * 400)} }

    Calendar::Drafter.new(item).run!

    expect(asked[:schema][:required]).to eq(%w[body facebook x])
    expect(asked[:prompt]).to include("The post: Same-day repairs")
    expect(item.reload).to have_attributes(state: "draft", draft_state: "ready", body: "Leaks fixed the day you call.")
    expect(item.deliveries.find_by(channel: facebook).text).to eq("Leak? We'll be there today.")
    expect(item.deliveries.find_by(channel: x).text.size).to eq(280)
  end

  it "plans a stretch of the calendar as ideas on dates, for the channels connected" do
    channel("linkedin")
    allow(Ai).to receive(:structured).and_return("items" => [
      {"date" => (Date.current + 3).iso8601, "kind" => "post", "title" => "What to do when a pipe bursts", "about" => "Steps.", "why" => "Search", "channels" => %w[linkedin x]},
      {"date" => (Date.current + 400).iso8601, "kind" => "social", "title" => "Too far", "about" => "", "why" => "", "channels" => []}
    ])
    created = Calendar::Planner.new(from: Date.current, to: Date.current + 27).run!
    expect(created.map(&:title)).to eq(["What to do when a pipe bursts"])
    expect(created.first).to have_attributes(state: "idea", kind: "post", source: "ai_plan")
    expect(created.first.channels.map(&:network)).to eq(["linkedin"])
  end
end
