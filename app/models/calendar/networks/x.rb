# frozen_string_literal: true

# X, through one X app with OAuth 2.0 (PKCE): the account signed in. A post
# is text up to 280 characters, the link counted as 23. Access tokens last
# two hours and renew with the refresh token (offline.access).
class Calendar::Networks::X < Calendar::Networks::Base
  KEY = "x"
  NAME = "X"
  API = "https://api.x.com/2"
  SCOPES = %w[tweet.read tweet.write users.read offline.access].freeze

  def authorize_url(redirect_uri:, state:, verifier:)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    "https://x.com/i/oauth2/authorize?#{URI.encode_www_form(response_type: "code", client_id: @settings.app_id(KEY), redirect_uri: redirect_uri, scope: SCOPES.join(" "),
      state: state, code_challenge: challenge, code_challenge_method: "S256")}"
  end

  def connect(code:, redirect_uri:, verifier:, by: nil)
    token, = request(:post, "#{API}/oauth2/token", headers: basic, form: {grant_type: "authorization_code", code: code, redirect_uri: redirect_uri,
                                                                       code_verifier: verifier, client_id: @settings.app_id(KEY)})
    me, = request(:get, "#{API}/users/me", headers: {"Authorization" => "Bearer #{token["access_token"]}"})
    user = me["data"].to_h
    [keep(network: "x", external_id: user["id"], name: user["name"], handle: user["username"], access_token: token["access_token"],
      refresh_token: token["refresh_token"], expires_in: token["expires_in"], by: by)]
  end

  def publish(delivery)
    text = [delivery.text, (delivery.item.link unless delivery.text.to_s.include?(delivery.item.link.to_s))].compact_blank.join(" ")
    answer, = request(:post, "#{API}/tweets", headers: {"Authorization" => "Bearer #{delivery.channel.access_token}"}, body: {text: text})
    id = answer.dig("data", "id")
    {external_id: id, external_url: "https://x.com/#{delivery.channel.handle || "i"}/status/#{id}"}
  end

  def refresh!(channel)
    raise Calendar::Error, "X's sign-in ran out: connect X again in Settings › Calendar" if channel.refresh_token.blank?

    token, = request(:post, "#{API}/oauth2/token", headers: basic, form: {grant_type: "refresh_token", refresh_token: channel.refresh_token, client_id: @settings.app_id(KEY)})
    channel.update!(access_token: token["access_token"], refresh_token: token["refresh_token"].presence || channel.refresh_token, expires_at: token["expires_in"].to_i.seconds.from_now)
  end

  private

  def basic = {"Authorization" => "Basic #{Base64.strict_encode64("#{@settings.app_id(KEY)}:#{@settings.app_secret(KEY)}")}"}
end
