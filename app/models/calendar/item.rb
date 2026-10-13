# frozen_string_literal: true

# One thing on the calendar: a social post, a post or page on the site (a
# CMS record, published on its own schedule), or a note. It goes from an idea
# to a draft, is scheduled for a time, and goes out then: its record
# publishes (the core's scheduled publishing) and each channel's delivery is
# sent (Calendar::DispatchJob, every minute), with the record's address as
# the link once it's live.
class Calendar::Item < ApplicationRecord
  KINDS = {"social" => "Social post", "post" => "Post on the site", "page" => "Page on the site", "note" => "Note"}.freeze
  STATES = %w[idea draft scheduled sending published failed].freeze
  WAIT_FOR_RECORD = 1.hour

  belongs_to :user, optional: true
  belongs_to :subject, polymorphic: true, optional: true
  belongs_to :asset, class_name: "::Asset", optional: true
  has_many :deliveries, -> { order(:id) }, dependent: :destroy, inverse_of: :item
  has_many :channels, through: :deliveries

  validates :title, presence: true, length: {maximum: 200}
  validates :kind, inclusion: {in: KINDS.keys}
  validates :state, inclusion: {in: STATES}
  validates :subject_type, inclusion: {in: %w[Page CollectionEntry]}, allow_nil: true
  validate :link_is_web

  scope :between, ->(from, to) { where(scheduled_at: from..to) }
  scope :unscheduled, -> { where(scheduled_at: nil).where.not(state: "published") }
  scope :due, ->(now = Time.current) { where(state: "scheduled").where(scheduled_at: ..now) }

  def kind_label = KINDS.fetch(kind)
  def social? = deliveries.any?
  def editable? = state.in?(%w[idea draft failed])

  # The address posts link to: the item's own, else its record's once the record is live.
  def link
    return link_url if link_url.present?

    subject.public_url if subject.respond_to?(:public_url) && subject.try(:status) == "published"
  end

  # A public address for the image, which Instagram and the Business Profile fetch themselves.
  def image_url
    url = asset&.then { it.respond_to?(:absolute_url) ? it.absolute_url : nil }
    url if url.to_s.start_with?("https://", "http://")
  end

  # The channels it goes to, setting each one's text where given ({channel_id => text}).
  def assign_channels(ids, texts = {})
    ids = Array(ids).compact_blank.map(&:to_i)
    deliveries.reject { it.sent? || ids.include?(it.channel_id) }.each(&:mark_for_destruction)
    ids.each do |id|
      delivery = deliveries.find { it.channel_id == id } || deliveries.build(channel_id: id)
      delivery.text = texts[id.to_s].to_s if texts.key?(id.to_s) && !delivery.sent?
    end
  end

  # Scheduled for a time: its record set to publish then (if it's a draft and the person may), its posts to go out.
  def schedule!(at, by:)
    raise Calendar::Error, "Choose when it goes out" if at.blank?

    transaction do
      update!(scheduled_at: at, state: "scheduled")
      if subject && subject.try(:status) != "published" && at > Time.current && can_publish_subject?(by)
        subject.update!(publish_at: at)
      end
    end
  end

  def unschedule! = update!(state: "draft")

  # Sends what's due: waits for its record to publish (for a while), then each channel's delivery.
  def dispatch!(now: Time.current)
    if subject && subject.try(:status) != "published"
      return update!(state: "scheduled") if scheduled_at > now - WAIT_FOR_RECORD

      return update!(state: "failed", notes: [notes, "Its #{subject_type.underscore.humanize.downcase} wasn't published, so nothing went out."].compact_blank.join("\n"))
    end

    deliveries.reject(&:sent?).each(&:send!)
    update!(state: deliveries.reload.all?(&:sent?) ? "published" : "failed")
  end

  # Each due item is claimed first (scheduled → sending), so two runs at once never post it twice;
  # one left sending by a run that died goes back to scheduled, and its sent deliveries aren't sent again.
  def self.dispatch_due(now: Time.current)
    where(state: "sending", updated_at: ..15.minutes.ago).update_all(state: "scheduled")
    due(now).pluck(:id).each do |id|
      next unless where(id: id, state: "scheduled").update_all(state: "sending", updated_at: now) == 1

      find(id).dispatch!(now: now)
    rescue => error
      Rails.error.report(error, handled: true)
    end
  end

  # The CMS record started for it: a draft post in the posts collection, or a draft page.
  def start_record!(by:)
    return subject if subject

    record = if kind == "post"
      collection = ::Collection.where(slug: %w[posts blog news articles]).first or raise Calendar::Error, "There's no posts collection to write it into"
      collection.entries.create!(title: title, slug: free_slug(collection.entries), status: "draft", locale: default_locale, body_markdown: body.to_s, frontmatter: {}, blocks: [])
    else
      ::Page.create!(title: title, slug: free_slug(::Page.where(parent_id: nil)), status: "draft", locale: default_locale, blocks: [], frontmatter: {})
    end
    record.track_creation if record.respond_to?(:track_creation)
    update!(subject: record, state: (state == "idea") ? "draft" : state)
    record
  end

  private

  def can_publish_subject?(user)
    user&.can?((subject_type == "Page") ? "pages:publish" : "entries:publish")
  end

  def free_slug(scope)
    base = title.parameterize.first(80).presence || "untitled"
    taken = scope.where("slug = ? OR slug LIKE ?", base, "#{base}-%").pluck(:slug)
    taken.include?(base) ? (2..).lazy.map { "#{base}-#{it}" }.find { !taken.include?(it) } : base
  end

  def default_locale = Setting.get("general")["default_locale"].presence || "en"

  def link_is_web
    errors.add(:link_url, "must start with https://") if link_url.present? && !link_url.match?(%r{\Ahttps?://\S+\z})
  end
end
