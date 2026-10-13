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

    # Where an item is, and what's next for it, in a line.
    def calendar_next_step(item)
      case item.state
      when "idea"
        if item.kind.in?(%w[post page]) && item.subject.nil? then "Next: write it. Start the #{item.kind} on the site (a draft), and share it on social once it's up."
        elsif item.social? then "Next: write it. Edit it, or have the AI draft each channel's post."
        else "Next: write it, and choose its channels."
        end
      when "draft" then item.scheduled_at ? "Next: schedule it for #{l item.scheduled_at, format: :long}, or another time." : "Next: give it a date and schedule it."
      when "scheduled" then "Scheduled: it goes out by itself #{l item.scheduled_at, format: :long}."
      when "sending" then "Going out now."
      when "published" then "Published."
      else "Some posts didn't go: see why below, then send them again."
      end
    end

    def calendar_when(item) = item.scheduled_at ? l(item.scheduled_at, format: :long) : "Not scheduled"
  end
end
