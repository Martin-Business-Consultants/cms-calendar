# frozen_string_literal: true

require "net/http"

# What every network does: sign a person in (authorize_url, connect) and
# publish a delivery, over Net::HTTP (a plugin may use only the gems the core
# bundles). `Calendar::Networks::Base.transport` stands in for the network in
# specs: ->(method, url, headers, body) { [status, body, headers] }.
class Calendar::Networks::Base
  TIMEOUT = 30

  class << self
    attr_accessor :transport
  end

  def initialize(settings: Calendar::Settings.current)
    @settings = settings
  end

  # Whether its app is set up in Settings › Calendar.
  def ready? = @settings.app?(self.class::KEY)

  private

  def request(method, url, headers: {}, body: nil, form: nil)
    transport = Calendar::Networks::Base.transport || method(:http)
    payload = form ? URI.encode_www_form(form) : (body && JSON.generate(body))
    headers = {"Content-Type" => form ? "application/x-www-form-urlencoded" : "application/json", "Accept" => "application/json"}.merge(headers)
    status, response, response_headers = transport.call(method, url, headers, payload)
    answer = parse(response)
    raise Calendar::Error, failure(status, answer) unless status.to_i.between?(200, 299)

    [answer, response_headers.to_h]
  end

  def get(url, **query) = request(:get, query.any? ? "#{url}?#{URI.encode_www_form(query)}" : url).first

  def failure(status, answer)
    detail = answer.dig("error", "message") || answer["error_description"] || answer["message"] || answer["detail"] ||
      Array(answer["errors"]).first&.then { it["message"] || it["detail"] } || (answer["error"].is_a?(String) ? answer["error"] : nil)
    "#{self.class::NAME} answered #{status}#{": #{detail.to_s.truncate(300)}" if detail}"
  end

  def parse(body)
    JSON.parse(body.to_s)
  rescue JSON::ParserError
    {}
  end

  def http(method, url, headers, body)
    uri = URI(url)
    request = {get: Net::HTTP::Get, post: Net::HTTP::Post, delete: Net::HTTP::Delete}.fetch(method).new(uri)
    headers.each { |name, value| request[name] = value }
    request.body = body if body
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: TIMEOUT) do |connection|
      response = connection.request(request)
      [response.code.to_i, response.body, response.each_header.to_h]
    end
  rescue Timeout::Error, IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError, Net::ProtocolError => problem
    raise Calendar::Error, "Couldn't reach #{self.class::NAME}: #{problem.class.name.demodulize}"
  end

  # Saves (or refreshes) a channel from what the network answered.
  def keep(network:, external_id:, name:, handle: nil, access_token:, refresh_token: nil, expires_in: nil, by: nil)
    channel = Calendar::Channel.find_or_initialize_by(network: network, external_id: external_id.to_s)
    channel.update!(name: name.to_s.truncate(120), handle: handle, access_token: access_token, refresh_token: refresh_token.presence || channel.refresh_token,
      expires_at: expires_in.present? ? expires_in.to_i.seconds.from_now : nil, state: "connected", error: nil, connected_by: by || channel.connected_by)
    channel
  end
end
