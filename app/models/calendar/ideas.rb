# frozen_string_literal: true

# What to put on the calendar, from the other plugins: Market's open
# opportunities for content, social, local and reviews; the posts and pages
# its AI suggested and nobody's sent; the searches Google says the site is
# close on; the searches Market's plan says to win. Each has a stable source
# key, so one taken onto the calendar isn't offered again.
class Calendar::Ideas
  Idea = Data.define(:source, :title, :detail, :kind, :origin)

  def all
    taken = Calendar::Item.where.not(source: nil).pluck(:source).to_set
    (opportunities + suggestions + searches).reject { taken.include?(it.source) }
  end

  def find(source) = all.find { it.source == source }

  private

  def opportunities
    return [] unless Calendar.market?

    ::Market::Opportunity.by_priority(::Market::Opportunity.active.where(channel: %w[content social local reviews seo brand email]).to_a).first(20).map do |opportunity|
      Idea.new(source: "market:opportunity:#{opportunity.id}", title: opportunity.title, detail: [opportunity.detail, opportunity.evidence].compact_blank.join(" "),
        kind: opportunity.channel.in?(%w[content seo]) ? "post" : "social", origin: "Market · #{opportunity.channel_label}")
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
        kind: "post", origin: "Google Search Console")
    end
  end
end
