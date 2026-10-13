# frozen_string_literal: true

require "calendar/version"
require "calendar/engine"

# A content calendar for the CMS: what goes out when, on the site (posts and
# pages, published on their schedule) and on the business's social channels
# (Facebook Pages, Instagram, LinkedIn, X and the Google Business Profile),
# planned from Market's plan and Google's searches, drafted per channel by
# the AI plugin, and sent by the CMS when it's due. Installed from its own
# repository; off by default.
module Calendar
  class Error < StandardError; end

  # Plugin tables are prefixed with the plugin's key.
  def self.table_name_prefix = "calendar_"

  def self.ai? = defined?(::Ai) && ::Ai.respond_to?(:available?) && ::Ai.available?
  def self.market? = defined?(::Market::Opportunity) && Cms::Plugins.enabled?(:market)
  def self.google_business? = defined?(::Google) && ::Google.respond_to?(:ready?) && ::Google.ready?(:business_profile)
end
