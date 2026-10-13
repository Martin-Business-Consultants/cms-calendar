# frozen_string_literal: true

# The AI plans a stretch of the calendar from the business's plan, its
# opportunities, the searches it wants to win and what Google says people
# search, and what's on the calendar already: posts for the site and social
# posts, on dates, each with what it's about and why. They land as ideas a
# person keeps, moves or deletes. Run in Calendar::PlanJob.
class Calendar::Planner
  MAX = 20
  SCHEMA = {
    type: "object", additionalProperties: false, required: %w[items],
    properties: {items: {type: "array", items: {
      type: "object", additionalProperties: false, required: %w[date kind title about why channels],
      properties: {
        date: {type: "string", description: "YYYY-MM-DD within the period."},
        kind: {type: "string", enum: %w[social post page], description: "social: a post on social channels; post: an article for the site's blog (shared on social too); page: a page the site needs."},
        title: {type: "string", description: "A working title or the post's hook."},
        about: {type: "string", description: "What it says, in two or three sentences someone could write from."},
        why: {type: "string", description: "Which part of the plan, search or opportunity it serves."},
        channels: {type: "array", items: {type: "string", enum: Calendar::Channel::NETWORKS.keys}}
      }
    }}}
  }.freeze

  def self.state = Setting.get(Calendar::Settings::KEY).slice("planning_since", "plan_error", "planned_at")
  def self.planning? = state["planning_since"].present? && Time.zone.parse(state["planning_since"]) > 15.minutes.ago

  def initialize(from:, to:, per_week: 3, user: nil)
    @from = from.to_date
    @to = to.to_date
    @per_week = per_week.to_i.clamp(1, 7)
    @user = user
  end

  def run!
    Setting.set(Calendar::Settings::KEY, "planning_since" => Time.current.iso8601, "plan_error" => nil)
    raise Calendar::Error, ::Ai.unavailable_reason.to_s unless Calendar.ai?

    answer = ::Ai.structured(purpose: "calendar_plan", system: system, prompt: prompt, schema: SCHEMA, user: @user)
    created = add(Array(answer["items"]))
    Setting.set(Calendar::Settings::KEY, "planning_since" => nil, "planned_at" => Time.current.iso8601)
    created
  rescue => error
    known = error.is_a?(Calendar::Error) || (defined?(::Ai::Error) && (error.is_a?(::Ai::Error) || error.is_a?(::Ai::Unavailable)))
    Setting.set(Calendar::Settings::KEY, "planning_since" => nil, "plan_error" => (known ? error.message : "#{error.class.name.demodulize}: #{error.message}").truncate(500))
    []
  end

  private

  def system
    [<<~TEXT, Calendar::Context.instructions].compact_blank.join("\n\n")
      You plan a small business's content calendar: posts for its website and social posts, to win its market. Serve the plan and its angle; turn the opportunities and the searches it wants to win (and those Google says it's close on) into content; mix helpful posts, proof (work done, customers), offers and local news. Content for a search coming into season goes on or before its date. Don't repeat what's on the calendar already.
      About #{@per_week} a week between #{@from.to_fs(:long)} and #{@to.to_fs(:long)}, at most #{MAX}, on weekdays unless the business suits weekends. Channels: only those connected, given below. Today is #{Date.current.to_fs(:long)}.
    TEXT
  end

  def prompt
    connected = Calendar::Channel.connected.distinct.pluck(:network)
    existing = Calendar::Item.where(scheduled_at: (@from - 30)..(@to + 1)).order(:scheduled_at).map { "#{it.scheduled_at.to_date}: #{it.title} (#{it.kind_label})" }
    [Calendar::Context.business,
      "Channels connected: #{connected.map { Calendar::Channel::NETWORKS.dig(it, :name) }.join(", ").presence || "none yet (plan for the site, and social in general)"}",
      ("On the calendar already:\n#{existing.join("\n")}" if existing.any?)].compact.join("\n\n")
  end

  def add(answers)
    channels = Calendar::Channel.connected.to_a
    answers.first(MAX).filter_map do |answer|
      date = Date.parse(answer["date"].to_s) rescue nil
      next unless date&.between?(@from, @to) && answer["title"].present?

      item = Calendar::Item.create!(title: answer["title"].to_s.strip.truncate(200), kind: answer["kind"].presence_in(%w[social post page]) || "social", state: "idea",
        scheduled_at: date.in_time_zone.change(hour: 10), body: answer["about"].to_s.strip, notes: answer["why"].to_s.strip.presence, source: "ai_plan", user: @user)
      networks = Array(answer["channels"])
      item.assign_channels(channels.select { networks.include?(it.network) }.map(&:id))
      item.save!
      item
    end
  end
end
