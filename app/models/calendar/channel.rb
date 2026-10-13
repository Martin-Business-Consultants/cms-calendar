# frozen_string_literal: true

# A social account the calendar posts to: a Facebook Page, an Instagram
# account, a LinkedIn profile or Page, an X account, the Google Business
# Profile. Its tokens are encrypted; one that has run out is renewed before
# it posts, or marked so a person connects it again.
class Calendar::Channel < ApplicationRecord
  NETWORKS = {
    "facebook" => {name: "Facebook", via: "Calendar::Networks::Meta", limit: 63_206},
    "instagram" => {name: "Instagram", via: "Calendar::Networks::Meta", limit: 2_200},
    "linkedin" => {name: "LinkedIn", via: "Calendar::Networks::LinkedIn", limit: 3_000},
    "x" => {name: "X", via: "Calendar::Networks::X", limit: 280},
    "google_business" => {name: "Google Business Profile", via: "Calendar::Networks::GoogleBusiness", limit: 1_500}
  }.freeze

  encrypts :access_token, :refresh_token

  belongs_to :connected_by, class_name: "User", optional: true
  has_many :deliveries, dependent: :destroy

  validates :network, inclusion: {in: NETWORKS.keys}
  validates :name, :external_id, presence: true

  scope :ordered, -> { in_order_of(:network, NETWORKS.keys).order(:name) }
  scope :connected, -> { where(state: "connected") }

  def network_name = NETWORKS.dig(network, :name)
  def limit = NETWORKS.dig(network, :limit)
  def client = NETWORKS.dig(network, :via).constantize.new
  def label = "#{network_name}: #{name}"
  def connected? = state == "connected"

  # Renews a token about to run out, where the network can.
  def fresh!
    return self unless expires_at && expires_at < 5.minutes.from_now

    raise Calendar::Error, "#{network_name}'s sign-in ran out: connect it again in Settings › Calendar" unless client.respond_to?(:refresh!)

    client.refresh!(self)
    self
  rescue Calendar::Error => error
    update!(state: "expired", error: error.message)
    raise
  end
end
