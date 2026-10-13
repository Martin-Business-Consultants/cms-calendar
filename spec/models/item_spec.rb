# frozen_string_literal: true

require "rails_helper"
require_relative "../support/calendar_helpers"

RSpec.describe Calendar::Item do
  let(:editor) { create(:user) }
  let(:facebook) { channel("facebook", external_id: "111", access_token: "page-token") }
  let(:instagram) { channel("instagram", external_id: "222", access_token: "page-token") }
  let(:linkedin) { channel("linkedin", external_id: "urn:li:organization:42") }
  let(:x) { channel("x", external_id: "77") }

  def item(**attributes)
    described_class.create!({title: "Same-day repairs", body: "We fix leaks the day you call.", link_url: "https://acme.example/emergency", state: "draft"}.merge(attributes))
  end

  before do
    switch_plugin :calendar, on: true
    fake_networks
  end

  it "sends each channel's post when it's due, to each network in its own shape" do
    post = item(scheduled_at: 1.minute.ago)
    post.assign_channels([facebook.id, linkedin.id, x.id], {linkedin.id.to_s => "We fix leaks (the same day) #plumbing"})
    post.save!
    post.update!(state: "scheduled")

    described_class.dispatch_due

    expect(post.reload.state).to eq("published")
    expect(form_of(request_to("/111/feed"))).to include("message" => "We fix leaks the day you call.", "link" => "https://acme.example/emergency", "access_token" => "page-token")
    linkedin_post = request_to("rest/posts")
    expect(linkedin_post[:headers]).to include("LinkedIn-Version" => Calendar::Networks::LinkedIn::VERSION, "X-Restli-Protocol-Version" => "2.0.0")
    expect(JSON.parse(linkedin_post[:body])).to include("author" => "urn:li:organization:42", "commentary" => "We fix leaks \\(the same day\\) \\#plumbing",
      "content" => {"article" => {"source" => "https://acme.example/emergency", "title" => "Same-day repairs"}})
    expect(JSON.parse(request_to("api.x.com/2/tweets")[:body])["text"]).to eq("We fix leaks the day you call. https://acme.example/emergency")
    expect(post.deliveries.map(&:external_url)).to contain_exactly("https://www.facebook.com/111_9", "https://www.linkedin.com/feed/update/urn:li:share:999", "https://x.com/acme/status/1800")
  end

  it "posts to Instagram in two steps with a public image, and refuses without one" do
    post = item(scheduled_at: 1.minute.ago)
    post.assign_channels([instagram.id])
    post.save!
    allow(post).to receive(:image_url).and_return("https://cdn.acme.example/van.jpg")
    post.deliveries.first.send!
    expect(form_of(request_to("/222/media"))).to include("image_url" => "https://cdn.acme.example/van.jpg", "caption" => "We fix leaks the day you call.")
    expect(form_of(request_to("/222/media_publish"))).to include("creation_id" => "container-1")
    expect(post.deliveries.first.reload).to have_attributes(state: "sent", external_url: "https://www.instagram.com/p/abc/")

    bare = item
    bare.assign_channels([instagram.id])
    bare.save!
    bare.deliveries.first.send!
    expect(bare.deliveries.first.reload).to have_attributes(state: "failed", error: "Instagram posts need an image: add one to the item")
  end

  it "keeps why a channel failed, sends the rest, and never sends one twice" do
    fake_networks(failing: {"api.x.com/2/tweets" => "duplicate content"})
    post = item(scheduled_at: 1.minute.ago)
    post.assign_channels([facebook.id, x.id])
    post.save!
    post.update!(state: "scheduled")

    described_class.dispatch_due
    expect(post.reload.state).to eq("failed")
    expect(post.deliveries.find_by(channel: x).error).to include("X answered 400", "duplicate content")

    fake_networks
    post.update!(state: "sending")
    post.dispatch!
    expect(post.reload.state).to eq("published")
    expect(network_requests.count { it[:url].include?("/111/feed") }).to eq(1)
  end

  it "claims an item before sending, so two runs at once post it once" do
    post = item(scheduled_at: 1.minute.ago)
    post.assign_channels([facebook.id])
    post.save!
    post.update!(state: "scheduled")
    described_class.where(id: post.id).update_all(state: "sending")

    described_class.dispatch_due
    expect(network_requests).to be_empty
  end

  it "schedules its record to publish then, and waits for it before posting the link" do
    entry_collection = Collection.create!(slug: "posts", name: "Posts", schema: {"fields" => []})
    post = item(kind: "post", link_url: nil, scheduled_at: 2.days.from_now)
    record = post.start_record!(by: editor)
    expect(record).to have_attributes(collection_id: entry_collection.id, status: "draft", title: "Same-day repairs")
    post.assign_channels([facebook.id])
    post.save!

    at = 2.days.from_now.change(sec: 0)
    post.schedule!(at, by: editor)
    expect(record.reload.publish_at).to eq(at)

    travel_to(at + 1.minute) do
      post.update_columns(state: "sending")
      post.dispatch!
      expect(post.reload.state).to eq("scheduled")
      expect(network_requests).to be_empty

      record.update!(status: "published")
      post.update_columns(state: "sending")
      post.dispatch!
      expect(post.reload.state).to eq("published")
      expect(form_of(request_to("/111/feed"))["link"]).to eq(record.public_url)
    end
  end

  it "renews an X token that has run out, and marks a channel whose sign-in is gone" do
    Calendar::Settings.update("x_app_id" => "x-client", "x_app_secret" => "x-secret")
    x.update!(expires_at: 1.minute.from_now, refresh_token: "x-refresh")
    x.fresh!
    expect(x.reload.access_token).to eq("x-token")
    expect(request_to("oauth2/token")[:headers]["Authorization"]).to eq("Basic #{Base64.strict_encode64("x-client:x-secret")}")

    x.update!(expires_at: 1.minute.ago, refresh_token: nil)
    expect { x.fresh! }.to raise_error(Calendar::Error, /connect X again/)
    expect(x.reload.state).to eq("expired")
  end

  it "refuses text too long for the channel" do
    post = item(body: "x" * 300)
    post.assign_channels([x.id])
    post.save!
    post.deliveries.first.send!
    expect(post.deliveries.first.reload.error).to include("Too long for X: 300 of 280")
  end
end
