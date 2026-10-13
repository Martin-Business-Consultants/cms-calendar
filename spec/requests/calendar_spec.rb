# frozen_string_literal: true

require "rails_helper"
require_relative "../support/calendar_helpers"

RSpec.describe "Calendar", type: :request do
  include ActiveJob::TestHelper

  let(:admin) { create(:user) }
  let(:agent) { create(:user, admin: false, role: create(:role, permissions: %w[calendar:read calendar:write])) }

  def api_headers(user) = {"Authorization" => "Bearer #{user.api_token!.token}", "Accept" => "application/json"}

  before do
    switch_plugin :calendar, on: true
    fake_networks
  end

  it "is a 404 while the plugin is off" do
    switch_plugin :calendar, on: false
    sign_in_as admin
    get calendar_path
    expect(response).to have_http_status(:not_found)
  end

  describe "the admin" do
    before { sign_in_as admin }

    it "shows the month beside the open item, the editor, ideas and settings" do
      facebook = channel("facebook")
      item = Calendar::Item.create!(title: "Same-day repairs", body: "Leaks fixed today", scheduled_at: Time.current.change(hour: 15), state: "draft")
      item.assign_channels([facebook.id])
      item.save!

      get calendar_path
      expect(response.body).to include("Same-day repairs", "calendar-chip--draft", "Not scheduled yet")
      get calendar_path(item: item.id)
      expect(response.body).to include("Leaks fixed today", "Acme on facebook", "Schedule", "Send now")
      [new_calendar_item_path, edit_calendar_item_path(item), calendar_ideas_path, settings_calendar_path].each do |path|
        get path
        expect(response).to have_http_status(:ok), "#{path}: #{response.status}"
      end
      get new_calendar_item_path
      expect(response.body).to include("title-input")
      expect(response.body).not_to include("<h1 class=\"page-title")
    end

    it "shows how the calendar works across the top, and takes an idea from Market's search onto its suggested date" do
      switch_plugin :market, on: true
      Market::SearchSnapshot.create!(domain: "acme.example", kind: "content_ideas", taken_at: Time.current,
        data: {"ideas" => [{"keyword" => "frozen pipes", "volume" => 900, "difficulty" => 30, "peak" => {"month" => (Date.current.month + 2) % 12 + 1, "lift" => 220}}]})

      get calendar_path
      expect(response.body).to include("How the calendar works", "1 waiting", "No social channels yet")
      get calendar_ideas_path
      expect(response.body).to include("What to write next", "Write about “frozen pipes”", "900 searches a month", "badge--warning")

      idea = Calendar::Ideas.new.find("market:idea:frozen-pipes")
      post calendar_ideas_path, params: {source: idea.source}
      item = Calendar::Item.find_by!(source: "market:idea:frozen-pipes")
      expect(item).to have_attributes(state: "idea", kind: "post", scheduled_at: idea.on.in_time_zone.change(hour: 10))
      expect(item.notes).to include("Market · coming into season", "900 searches a month")
      get calendar_path(item: item.id)
      expect(response.body).to include("Next: write it. Start the post on the site")
    end

    it "adds an item with each channel's text, schedules it, and takes it off" do
      facebook = channel("facebook")
      x = channel("x")
      post calendar_items_path, params: {item: {title: "Spring check-up", kind: "social", body: "Book a check-up", channel_ids: ["", facebook.id, x.id], texts: {x.id.to_s => "Check-up time"}}}
      item = Calendar::Item.last
      expect(item.deliveries.map { [it.channel.network, it.text] }).to contain_exactly(["facebook", nil], ["x", "Check-up time"])

      at = 3.days.from_now.change(hour: 9, min: 30)
      post calendar_item_schedule_path(item), params: {at: at.strftime("%Y-%m-%dT%H:%M")}
      expect(item.reload).to have_attributes(state: "scheduled", scheduled_at: at)
      delete calendar_item_schedule_path(item)
      expect(item.reload.state).to eq("draft")
    end

    it "sends now, and says what didn't go" do
      x = channel("x")
      item = Calendar::Item.create!(title: "Now", body: "Open today", state: "draft")
      item.assign_channels([x.id])
      item.save!
      post calendar_item_dispatch_path(item)
      expect(flash[:notice]).to eq("Sent")
      expect(item.reload.state).to eq("published")
    end

    it "connects Meta, LinkedIn and X through their sign-ins, checking the state, with PKCE for X" do
      Calendar::Settings.update("meta_app_id" => "fb-app", "meta_app_secret" => "fb-secret", "linkedin_app_id" => "li-app", "linkedin_app_secret" => "li-secret",
        "x_app_id" => "x-app", "x_app_secret" => "x-secret")

      get connect_settings_calendar_path(network: "meta")
      expect(URI(response.location).host).to eq("www.facebook.com")
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]
      get callback_settings_calendar_path(network: "meta"), params: {code: "c", state: "forged"}
      expect(flash[:alert]).to include("didn't start here")
      get connect_settings_calendar_path(network: "meta")
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]
      get callback_settings_calendar_path(network: "meta"), params: {code: "c", state: state}
      expect(Calendar::Channel.pluck(:network, :name)).to contain_exactly(["facebook", "Acme Plumbing"], ["instagram", "acmeplumbing"])
      expect(Calendar::Channel.find_by(network: "facebook").access_token).to eq("page-token")

      get connect_settings_calendar_path(network: "linkedin")
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]
      get callback_settings_calendar_path(network: "linkedin"), params: {code: "c", state: state}
      expect(Calendar::Channel.where(network: "linkedin").pluck(:external_id)).to contain_exactly("urn:li:person:abc123", "urn:li:organization:42")

      get connect_settings_calendar_path(network: "x")
      query = Rack::Utils.parse_query(URI(response.location).query)
      expect(query).to include("code_challenge_method" => "S256")
      get callback_settings_calendar_path(network: "x"), params: {code: "c", state: query["state"]}
      verifier = form_of(request_to("api.x.com/2/oauth2/token"))["code_verifier"]
      expect(Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)).to eq(query["code_challenge"])
      expect(Calendar::Channel.find_by(network: "x")).to have_attributes(handle: "acme", refresh_token: "x-refresh")

      get settings_calendar_path
      expect(response.body).to include("Acme Plumbing", "@acme")
      expect(response.body).not_to include("page-token", "x-secret", "fb-secret")
    end
  end

  describe "the API" do
    it "lets an agent write and draft but not schedule: going out is a person's call" do
      facebook = channel("facebook")
      post "/api/calendar/items", params: {item: {title: "Tips", body: "Five tips", channel_ids: [facebook.id]}}, headers: api_headers(agent), as: :json
      expect(response).to have_http_status(:created)
      id = response.parsed_body.dig("item", "id")

      post "/api/calendar/items/#{id}/schedule", params: {at: 2.days.from_now.iso8601}, headers: api_headers(agent), as: :json
      expect(response).to have_http_status(:forbidden)

      post "/api/calendar/items/#{id}/schedule", params: {at: 2.days.from_now.iso8601}, headers: api_headers(admin), as: :json
      expect(response.parsed_body.dig("item", "state")).to eq("scheduled")

      get "/api/calendar/items", params: {from: Date.current.iso8601, to: (Date.current + 7).iso8601}, headers: api_headers(agent)
      expect(response.parsed_body["items"].first).to include("title" => "Tips", "deliveries" => [a_hash_including("network" => "facebook", "state" => "pending")])
      get "/api/calendar/channels", headers: api_headers(agent)
      expect(response.body).not_to include("token-facebook")
    end

    it "is listed in the manifest" do
      get "/api/manifest", headers: api_headers(admin)
      expect(response.body).to include("/api/calendar/items")
    end
  end
end
