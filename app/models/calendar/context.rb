# frozen_string_literal: true

# What the AI is told about the business for the calendar: the brand brief,
# Market's profile and plan (the big picture and the angle to win on), the
# searches coming into season and worth writing about, and Google's searches
# when they're there. Every draft and plan serves that.
module Calendar::Context
  module_function

  def instructions
    brand = defined?(::BrandBrief) ? ::BrandBrief.to_h.map { |field, text| "#{field.to_s.humanize}: #{text}" }.join("\n") : ""
    guidance = Calendar::Settings.current.social_guidance
    [("The brand brief the owners wrote:\n#{brand}" if brand.present?), ("How social posts should read: #{guidance}" if guidance.present?)].compact.join("\n\n")
  end

  def business
    parts = []
    if defined?(::Market::Profile) && Cms::Plugins.enabled?(:market)
      profile = ::Market::Profile.current
      parts << "The business: #{profile.business_name} (#{profile.website})"
      parts.concat(::Market::Profile::FIELDS.filter_map { |field| "#{::Market::Profile::LABELS[field]}: #{profile.public_send(field)}" if profile.public_send(field) })
      plan = ::Market::Plan.where(state: "ready").latest_first.first
      parts << "The plan's big picture: #{plan.summary}" if plan&.summary.present?
      parts << "The angle to win on: #{plan.positioning}" if plan&.positioning.present?
      opportunities = ::Market::Opportunity.active.to_a
      parts << "Opportunities planned: #{::Market::Opportunity.by_priority(opportunities).first(12).map { "#{it.title} (#{it.channel_label})" }.join("; ")}" if opportunities.any?
      keywords = ::Market::Keyword.ordered.pluck(:keyword)
      parts << "Searches it wants to win: #{keywords.first(20).join(", ")}" if keywords.any?
    end
    ideas = Calendar::Ideas.new.all
    seasonal = ideas.select(&:on)
    parts << "Coming into season (publish by the date given):\n#{seasonal.first(10).map { "- #{it.title}, by #{it.on.to_fs(:long)} (#{it.facts})" }.join("\n")}" if seasonal.any?
    writing = ideas.select { it.source.start_with?("market:idea:") && !it.on }
    parts << "Searches worth writing about (searches a month, difficulty out of 100): #{writing.first(10).map { "#{it.title.delete_prefix("Write about ")} (#{it.facts})" }.join("; ")}" if writing.any?
    console = defined?(::Google) && ::Google.respond_to?(:search_console) ? ::Google.search_console : nil
    if console&.queries&.any?
      parts << "What people search on Google to find it (Search Console, 28 days): #{console.queries.first(15).map { it["keys"][0] }.join(", ")}"
      parts << "Searches it's close on (worth content): #{console.striking_distance(limit: 10).map { it["keys"][0] }.join(", ")}"
    end
    parts.join("\n").presence || "Nothing is known about the business beyond the brand brief."
  end
end
