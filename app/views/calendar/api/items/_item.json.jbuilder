# frozen_string_literal: true

json.call(item, :id, :title, :kind, :state, :scheduled_at, :body, :link_url, :asset_id, :notes, :source, :draft_state, :draft_error, :created_at, :updated_at)
json.link item.link
json.image_url item.image_url
json.record(item.subject && {type: item.subject_type, id: item.subject_id, title: item.subject.title, status: item.subject.try(:status)})
json.deliveries item.deliveries do |delivery|
  json.call(delivery, :id, :channel_id, :text, :state, :external_url, :error, :sent_at)
  json.channel delivery.channel.label
  json.network delivery.channel.network
end
