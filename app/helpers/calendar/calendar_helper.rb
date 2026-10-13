# frozen_string_literal: true

module Calendar
  module CalendarHelper
    STATE_CLASSES = {"idea" => "calendar-chip--idea", "draft" => "calendar-chip--draft", "scheduled" => "calendar-chip--scheduled",
                     "sending" => "calendar-chip--scheduled", "published" => "calendar-chip--published", "failed" => "calendar-chip--failed"}.freeze
    NETWORK_SHORT = {"facebook" => "f", "instagram" => "ig", "linkedin" => "in", "x" => "x", "google_business" => "G"}.freeze

    def calendar_chip_class(item) = STATE_CLASSES.fetch(item.state)

    def calendar_state_tag(item)
      tag.span(item.state.capitalize, class: {"published" => "badge badge--success", "failed" => "badge badge--danger", "scheduled" => "badge badge--info", "sending" => "badge badge--info"}.fetch(item.state, "badge"))
    end

    # A channel's network, small: "ig", "in", "x".
    def calendar_network(network, title: nil)
      tag.span(NETWORK_SHORT.fetch(network, network.first), class: "calendar-net", title: title || Calendar::Channel::NETWORKS.dig(network, :name))
    end

    def calendar_when(item) = item.scheduled_at ? l(item.scheduled_at, format: :long) : "Not scheduled"
  end
end
