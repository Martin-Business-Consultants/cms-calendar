# frozen_string_literal: true

# The social networks, answered without the network: each request matched by
# a fragment of its address, and recorded.
module CalendarHelpers
  ANSWERS = {
    "graph.facebook.com/v24.0/oauth/access_token" => {"access_token" => "fb-user-token", "expires_in" => 5_184_000},
    "graph.facebook.com/v24.0/me/accounts" => {"data" => [{"id" => "111", "name" => "Acme Plumbing", "access_token" => "page-token",
                                                          "instagram_business_account" => {"id" => "222", "username" => "acmeplumbing"}}]},
    "/111/feed" => {"id" => "111_9"},
    "/111/photos" => {"id" => "8", "post_id" => "111_8"},
    "/222/media_publish" => {"id" => "333"},
    "/222/media" => {"id" => "container-1"},
    "graph.facebook.com/v24.0/333" => {"permalink" => "https://www.instagram.com/p/abc/"},
    "linkedin.com/oauth/v2/accessToken" => {"access_token" => "li-token", "expires_in" => 5_184_000, "refresh_token" => "li-refresh"},
    "api.linkedin.com/v2/userinfo" => {"sub" => "abc123", "name" => "Pat Acme"},
    "rest/organizationAcls" => {"elements" => [{"organization" => "urn:li:organization:42"}]},
    "rest/organizations/42" => {"localizedName" => "Acme Plumbing"},
    "api.linkedin.com/rest/posts" => :linkedin_post,
    "api.x.com/2/oauth2/token" => {"access_token" => "x-token", "expires_in" => 7200, "refresh_token" => "x-refresh"},
    "api.x.com/2/users/me" => {"data" => {"id" => "77", "name" => "Acme", "username" => "acme"}},
    "api.x.com/2/tweets" => {"data" => {"id" => "1800"}}
  }.freeze

  def network_requests = (@network_requests ||= [])

  def fake_networks(failing: {})
    Calendar::Networks::Base.transport = lambda do |method, url, headers, body|
      network_requests << {method: method, url: url, headers: headers, body: body}
      fragment = failing.keys.find { url.include?(it) }
      next [400, JSON.generate({"error" => {"message" => failing[fragment]}}), {}] if fragment

      _, answer = ANSWERS.find { |key, _| url.include?(key) }
      next [201, "", {"x-restli-id" => "urn:li:share:999"}] if answer == :linkedin_post

      answer ? [200, JSON.generate(answer), {}] : [404, "{}", {}]
    end
  end

  def request_to(fragment) = network_requests.find { it[:url].include?(fragment) }
  def form_of(request) = Rack::Utils.parse_query(request[:body])

  def channel(network, external_id: "#{network}-1", **attributes)
    Calendar::Channel.create!({network: network, name: "Acme on #{network}", external_id: external_id, access_token: "token-#{network}", handle: "acme"}.merge(attributes))
  end
end

RSpec.configure do |config|
  config.include CalendarHelpers
  config.after { Calendar::Networks::Base.transport = nil }
end
