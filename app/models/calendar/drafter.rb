# frozen_string_literal: true

# The AI writes an item's text for each channel it goes to, in each one's
# shape and length (X's 280 characters, Instagram's hashtags, LinkedIn's
# professional tone, the Business Profile's local offer), from the item, its
# link and the business's plan. It fills only deliveries not yet sent; a
# person reads and edits before scheduling. Run in Calendar::DraftJob.
class Calendar::Drafter
  STYLE = {
    "facebook" => "Facebook Page: conversational, 1–3 short paragraphs, a clear call to action, the link on its own line if there is one.",
    "instagram" => "Instagram caption: a strong first line, short lines, up to 5 relevant hashtags at the end; no link (say \"link in bio\" if it matters).",
    "linkedin" => "LinkedIn: professional and specific, a hook in the first line, 2–4 short paragraphs, up to 3 hashtags.",
    "x" => "X: one or two sentences, at most 250 characters so the link fits, at most one hashtag.",
    "google_business" => "Google Business Profile post: local and practical, what's on offer and for whom, under 1,000 characters, no hashtags or phone numbers."
  }.freeze

  def initialize(item, user: nil)
    @item = item
    @user = user
  end

  def run!
    @item.update_columns(draft_state: "running", draft_error: nil, updated_at: Time.current)
    raise Calendar::Error, ::Ai.unavailable_reason.to_s unless Calendar.ai?

    networks = @item.deliveries.reject(&:sent?).map { it.channel.network }.uniq
    raise Calendar::Error, "Choose the channels it goes to first" if networks.empty?

    answer = ::Ai.structured(purpose: "calendar_draft", system: system, prompt: prompt, schema: schema(networks), user: @user)
    @item.deliveries.reject(&:sent?).each do |delivery|
      text = answer[delivery.channel.network].to_s.strip
      delivery.update!(text: text.first(delivery.channel.limit)) if text.present?
    end
    @item.update!(body: answer["body"].to_s.strip.presence || @item.body, draft_state: "ready", state: (@item.state == "idea") ? "draft" : @item.state)
  rescue => error
    known = error.is_a?(Calendar::Error) || (defined?(::Ai::Error) && (error.is_a?(::Ai::Error) || error.is_a?(::Ai::Unavailable)))
    Rails.logger.error("[calendar] drafting item #{@item.id}: #{error.class}: #{error.message}") unless known
    @item.update_columns(draft_state: "failed", draft_error: (known ? error.message : "#{error.class.name.demodulize}: #{error.message}").truncate(500), updated_at: Time.current)
  end

  def schema(networks)
    {type: "object", additionalProperties: false, required: ["body", *networks],
     properties: {body: {type: "string", description: "The post's core message, in plain words, for the calendar."},
                  **networks.to_h { [it, {type: "string", description: STYLE.fetch(it)}] }}}
  end

  private

  def system
    [<<~TEXT, Calendar::Context.instructions].compact_blank.join("\n\n")
      You write a small business's social posts, one for each channel it goes to, in that channel's style and length. Everything serves the business's plan and angle, given below.
      Write as the business, in its voice. Be specific and useful; never invent offers, prices, awards, reviews or facts that aren't given. Today is #{Date.current.to_fs(:long)}.
    TEXT
  end

  def prompt
    [Calendar::Context.business,
      "The post: #{@item.title}",
      ("What it's about: #{@item.body}" if @item.body.present?),
      ("It links to: #{@item.link}" if @item.link),
      ("It goes out: #{@item.scheduled_at.to_fs(:long)}" if @item.scheduled_at),
      ("Its page on the site: “#{@item.subject.title}”" if @item.subject),
      ("It has a photo." if @item.asset)].compact.join("\n\n")
  end
end
