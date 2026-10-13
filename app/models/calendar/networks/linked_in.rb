# frozen_string_literal: true

# LinkedIn, through one LinkedIn app: the person's own profile (Share on
# LinkedIn) and the company Pages they administer (the Community Management
# API, which LinkedIn grants an app on request; without it, only the
# profile). A post is commentary with the link as an article. Tokens last
# 60 days; an app LinkedIn has granted refresh tokens renews itself.
class Calendar::Networks::LinkedIn < Calendar::Networks::Base
  KEY = "linkedin"
  NAME = "LinkedIn"
  API = "https://api.linkedin.com"
  VERSION = "202509"
  SCOPES = %w[openid profile w_member_social w_organization_social r_organization_social].freeze

  def authorize_url(redirect_uri:, state:, verifier: nil)
    "https://www.linkedin.com/oauth/v2/authorization?#{URI.encode_www_form(response_type: "code", client_id: @settings.app_id(KEY), redirect_uri: redirect_uri, state: state, scope: SCOPES.join(" "))}"
  end

  def connect(code:, redirect_uri:, verifier: nil, by: nil)
    token, = request(:post, "https://www.linkedin.com/oauth/v2/accessToken",
      form: {grant_type: "authorization_code", code: code, redirect_uri: redirect_uri, client_id: @settings.app_id(KEY), client_secret: @settings.app_secret(KEY)})
    auth = {"Authorization" => "Bearer #{token["access_token"]}"}
    me, = request(:get, "#{API}/v2/userinfo", headers: auth)
    fields = {access_token: token["access_token"], refresh_token: token["refresh_token"], expires_in: token["expires_in"], by: by}
    person = keep(network: "linkedin", external_id: "urn:li:person:#{me["sub"]}", name: me["name"], **fields)
    [person, *organizations(auth).map { |urn, name| keep(network: "linkedin", external_id: urn, name: name, **fields) }]
  end

  def publish(delivery)
    channel = delivery.channel
    item = delivery.item
    body = {author: channel.external_id, commentary: escape(delivery.text), visibility: "PUBLIC", lifecycleState: "PUBLISHED", isReshareDisabledByAuthor: false,
            distribution: {feedDistribution: "MAIN_FEED", targetEntities: [], thirdPartyDistributionChannels: []}}
    body[:content] = {article: {source: item.link, title: item.title.truncate(200)}} if item.link
    _, headers = request(:post, "#{API}/rest/posts", headers: rest_headers(channel.access_token), body: body)
    urn = headers["x-restli-id"] || headers["X-RestLi-Id"]
    {external_id: urn, external_url: urn && "https://www.linkedin.com/feed/update/#{urn}"}
  end

  def refresh!(channel)
    raise Calendar::Error, "LinkedIn's sign-in ran out: connect LinkedIn again in Settings › Calendar" if channel.refresh_token.blank?

    token, = request(:post, "https://www.linkedin.com/oauth/v2/accessToken",
      form: {grant_type: "refresh_token", refresh_token: channel.refresh_token, client_id: @settings.app_id(KEY), client_secret: @settings.app_secret(KEY)})
    channel.update!(access_token: token["access_token"], refresh_token: token["refresh_token"].presence || channel.refresh_token, expires_at: token["expires_in"].to_i.seconds.from_now)
  end

  private

  def rest_headers(token) = {"Authorization" => "Bearer #{token}", "LinkedIn-Version" => VERSION, "X-Restli-Protocol-Version" => "2.0.0"}

  # The Pages the person administers: {urn => name}; none when LinkedIn hasn't granted the app the organization scopes.
  def organizations(auth)
    acls, = request(:get, "#{API}/rest/organizationAcls?q=roleAssignee&role=ADMINISTRATOR&state=APPROVED", headers: rest_headers(auth["Authorization"].delete_prefix("Bearer ")))
    Array(acls["elements"]).filter_map { it["organization"] }.uniq.to_h do |urn|
      organization, = request(:get, "#{API}/rest/organizations/#{urn.split(":").last}", headers: rest_headers(auth["Authorization"].delete_prefix("Bearer ")))
      [urn, organization["localizedName"].presence || urn]
    end
  rescue Calendar::Error
    {}
  end

  # LinkedIn's "little text" format reserves these characters.
  def escape(text) = text.to_s.gsub(/([\\|{}@\[\]()<>#*_~])/) { "\\#{$1}" }
end
