# frozen_string_literal: true

# One item going to one channel: the text written for that channel, and
# what came of sending it (the post's address, or why it failed).
class Calendar::Delivery < ApplicationRecord
  STATES = %w[pending sent failed].freeze
  MAX_ATTEMPTS = 3

  belongs_to :item
  belongs_to :channel

  validates :state, inclusion: {in: STATES}
  validate :fits

  def sent? = state == "sent"
  def text_or_body = text.presence || item.body.to_s

  # Sends it now; never raises: what went wrong is kept.
  def send!
    return if sent?

    self.text = text_or_body
    raise Calendar::Error, "Too long for #{channel.network_name}: #{text.size} of #{channel.limit} characters" if text.size > channel.limit

    result = channel.fresh!.client.publish(self)
    update!(state: "sent", external_id: result[:external_id], external_url: result[:external_url], error: nil, sent_at: Time.current, attempts: attempts + 1)
  rescue Calendar::Error => error
    update_columns(state: "failed", error: error.message.truncate(500), attempts: attempts + 1, updated_at: Time.current)
  rescue => error
    Rails.logger.error("[calendar] delivery #{id}: #{error.class}: #{error.message}")
    update_columns(state: "failed", error: "#{error.class.name.demodulize}: #{error.message}".truncate(500), attempts: attempts + 1, updated_at: Time.current)
  end

  private

  def fits
    errors.add(:text, "is too long for #{channel.network_name} (#{text.size} of #{channel.limit})") if channel && text.to_s.size > channel.limit
  end
end
