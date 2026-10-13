# frozen_string_literal: true

# What to put on the calendar, from the other plugins, the most timely
# first: searches coming into season (a tracked one, or one worth writing
# about, that peaks within a few months: written two months before, it has
# time to rank), Market's open opportunities for content, social, local and
# reviews, the posts and pages its AI suggested and nobody's sent, the
# searches Google says the site is close on, then the other searches
# Market found worth writing about. Each has a stable source key, so one
# taken onto the calendar isn't offered again, and some a date to put it on.
class Calendar::Ideas
  Idea = Data.define(:source, :title, :detail, :kind, :origin, :facts, :on, :timely) do
    def initialize(source:, title:, detail:, kind:, origin:, facts: nil, on: nil, timely: false) = super
  end

  WRITING = 12
  SEASON_AHEAD = 2 # months before a peak to publish
  SEASON_WINDOW = 5 # months ahead a peak counts as coming

  def all
    taken = Calendar::Item.where.not(source: nil).pluck(:source).to_set
    ideas = seasons + opportunities + suggestions + searches + writing
    ideas.uniq(&:source).reject { taken.include?(it.source) }.sort_by.with_index { |idea, index| [idea.timely ? 0 : 1, idea.on || Date.new(9999), index] }
  end

  def find(source) = all.find { it.source == source }

  # The date to publish for a search that peaks in `month` (1–12): two months before, or soon when that's passed; nil when the peak is far off.
  def self.publish_on(month, today: Date.current)
    return unless month.to_i.between?(1, 12)

    peak = Date.new(today.year, month.to_i, 1)
    peak = peak.next_year if peak < today.beginning_of_month
    return if peak > today.beginning_of_month >> SEASON_WINDOW

    on = [peak << SEASON_AHEAD, today + 1].max
    on += 1 while on.saturday? || on.sunday?
    on
  end

  private

  def opportunities
    return [] unless Calendar.market?

    ::Market::Opportunity.by_priority(::Market::Opportunity.active.where(channel: %w[content social local reviews seo brand email]).includes(:goal).to_a).first(20).map do |opportunity|
      Idea.new(source: "market:opportunity:#{opportunity.id}", title: opportunity.title, detail: [opportunity.detail, opportunity.evidence].compact_blank.join(" "),
        kind: opportunity.channel.in?(%w[content seo local]) ? "post" : "social", origin: "Market · #{opportunity.channel_label}",
        facts: [("For: #{opportunity.goal.title}" if opportunity.goal), "#{opportunity.impact.capitalize} impact", opportunity.horizon_label].compact.join(" · "),
        timely: opportunity.horizon == "now")
    end
  end

  def suggestions
    return [] unless Calendar.market? && defined?(::Market::Workup)

    ::Market::Workup.where(state: "ready").latest_first.limit(20).flat_map do |workup|
      workup.changes.each_with_index.filter_map do |change, index|
        next unless change["kind"].in?(%w[new_post new_page]) && !workup.sent_for(index)

        Idea.new(source: "market:workup:#{workup.id}:#{index}", title: change["page_title"].presence || change["title"], detail: change["why"].to_s,
          kind: (change["kind"] == "new_post") ? "post" : "page", origin: "Market · AI suggestion")
      end
    end
  end

  def searches
    console = defined?(::Google) && ::Google.respond_to?(:search_console) ? ::Google.search_console : nil
    rows = console ? console.striking_distance(limit: 10) : []
    rows.map do |row|
      Idea.new(source: "google:search:#{row["keys"][0].parameterize}", title: "Write about “#{row["keys"][0]}”",
        detail: "Google shows the site #{row["impressions"]} times a month for it, on average at #{row["position"].to_f.round(1)}: a post that answers it can move it up.",
        kind: "post", origin: "Google Search Console", facts: "#{row["impressions"]} impressions · position #{row["position"].to_f.round(1)}")
    end
  end

  # Market's searches worth writing about (DataForSEO keyword ideas): easiest and biggest first; those coming into season are in #seasons.
  def writing
    content_ideas.reject { season_month(it["peak"]) }.sort_by { [it["difficulty"].to_i > 40 ? 1 : 0, -it["volume"].to_i] }.first(WRITING).map { writing_idea(it) }
  end

  # Searches that peak within the next few months: the tracked ones (Market's keyword facts) and those worth writing about.
  def seasons
    return [] unless Calendar.market? && defined?(::Market::Seasons)

    tracked = market_snapshot("keyword_facts")&.data&.dig("keywords").to_h.filter_map do |keyword, fact|
      peak = ::Market::Seasons.peak(fact["months"])
      on = season_month(peak) or next
      Idea.new(source: "market:season:#{keyword.parameterize}", title: "Get ready for “#{keyword}” season",
        detail: "Searches for “#{keyword}” peak in #{::Market::Seasons.month_name(peak["month"])}, #{peak["lift"]}% above the year's average. A post, an offer or an update to its page published by #{on.strftime("%B %-d")} has time to rank before then; social posts can follow it.",
        kind: "post", origin: "Market · a tracked search's season", facts: season_facts(fact["volume"], nil, peak), on: on, timely: true)
    end
    tracked + content_ideas.select { season_month(it["peak"]) }.map { writing_idea(it) }
  end

  def writing_idea(idea)
    keyword = idea["keyword"]
    on = season_month(idea["peak"])
    detail = [(idea["question"] ? "People ask this: a post that answers it plainly, with an FAQ, can rank for it and be quoted by AI answers." : "A post that covers it well can rank for it."),
      ("It peaks in #{::Market::Seasons.month_name(idea["peak"]["month"])}: publish by #{on.strftime("%B %-d")}." if on)].compact.join(" ")
    Idea.new(source: "market:idea:#{keyword.parameterize}", title: "Write about “#{keyword}”", detail: detail, kind: "post",
      origin: on ? "Market · coming into season" : "Market · worth writing about", facts: season_facts(idea["volume"], idea["difficulty"], idea["peak"]), on: on, timely: on.present?)
  end

  def season_facts(volume, difficulty, peak)
    [("#{volume.to_i.to_fs(:delimited)} searches a month" if volume.to_i.positive?), ("difficulty #{difficulty}" if difficulty),
      ("peaks in #{::Market::Seasons.month_name(peak["month"])}" if peak.is_a?(Hash))].compact.join(" · ").presence
  end

  def season_month(peak) = peak.is_a?(Hash) ? self.class.publish_on(peak["month"]) : nil

  def content_ideas
    @content_ideas ||= Calendar.market? ? Array(market_snapshot("content_ideas")&.data&.dig("ideas")).select { it.is_a?(Hash) && it["keyword"].present? } : []
  end

  def market_snapshot(kind)
    return unless defined?(::Market::SearchSnapshot)

    ::Market::SearchSnapshot.where(competitor_id: nil, kind: kind).latest_first.first
  end
end
