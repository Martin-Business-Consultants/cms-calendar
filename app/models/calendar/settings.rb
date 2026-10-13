# frozen_string_literal: true

# Settings › Calendar, kept in the core's Setting "calendar": the developer
# app each network signs in through (its ID here, its secret among the
# Setting's secrets), and the AI's guidance for social posts.
class Calendar::Settings
  KEY = "calendar"
  APPS = {"meta" => "Meta (Facebook and Instagram)", "linkedin" => "LinkedIn", "x" => "X"}.freeze

  def self.current = new(Setting.get(KEY))

  def initialize(data)
    @data = data.to_h.stringify_keys
  end

  def app_id(network) = @data["#{network}_app_id"].presence
  def app_secret(network) = Setting.secret(KEY, "#{network}_app_secret").presence
  def app?(network) = app_id(network).present? && app_secret(network).present?

  # How social posts should read, beyond the brand brief: hashtags, emoji, sign-off.
  def social_guidance = @data["social_guidance"].to_s

  def self.update(params)
    params = params.to_h.stringify_keys
    data = APPS.keys.filter_map { |network| ["#{network}_app_id", params["#{network}_app_id"].to_s.strip.presence] if params.key?("#{network}_app_id") }.to_h
    data["social_guidance"] = params["social_guidance"].to_s.strip if params.key?("social_guidance")
    Setting.set(KEY, data) if data.any?
    secrets = APPS.keys.filter_map { |network| ["#{network}_app_secret", params["#{network}_app_secret"].to_s.strip] if params["#{network}_app_secret"].present? }.to_h
    Setting.set_secret(KEY, secrets) if secrets.any?
    current
  end

  def to_h = APPS.keys.to_h { [it, {app_id: app_id(it), secret_set: app_secret(it).present?}] }.merge(social_guidance: social_guidance)
end
