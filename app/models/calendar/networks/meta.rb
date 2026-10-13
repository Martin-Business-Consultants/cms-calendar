# frozen_string_literal: true

# Facebook Pages and Instagram professional accounts, through one Meta app
# (Facebook Login for Business). Signing in gives a long-lived user token;
# each Page the person manages comes with its own Page token (which doesn't
# run out), and each Page's linked Instagram account is posted to with it.
# A Page post is a message with a link, or a photo with a caption; Instagram
# takes a photo (a public image address) with a caption, never a link.
class Calendar::Networks::Meta < Calendar::Networks::Base
  KEY = "meta"
  NAME = "Meta"
  GRAPH = "https://graph.facebook.com/v24.0"
  SCOPES = %w[pages_show_list pages_read_engagement pages_manage_posts instagram_basic instagram_content_publish business_management].freeze

  def authorize_url(redirect_uri:, state:, verifier: nil)
    "https://www.facebook.com/v24.0/dialog/oauth?#{URI.encode_www_form(client_id: @settings.app_id(KEY), redirect_uri: redirect_uri, state: state, scope: SCOPES.join(","), response_type: "code")}"
  end

  # Every Page, and each Page's Instagram account, as a channel.
  def connect(code:, redirect_uri:, verifier: nil, by: nil)
    short = get("#{GRAPH}/oauth/access_token", client_id: @settings.app_id(KEY), client_secret: @settings.app_secret(KEY), redirect_uri: redirect_uri, code: code)
    long = get("#{GRAPH}/oauth/access_token", grant_type: "fb_exchange_token", client_id: @settings.app_id(KEY), client_secret: @settings.app_secret(KEY),
      fb_exchange_token: short["access_token"])
    pages = get("#{GRAPH}/me/accounts", fields: "id,name,access_token,instagram_business_account{id,username}", access_token: long["access_token"], limit: 100)
    Array(pages["data"]).flat_map do |page|
      facebook = keep(network: "facebook", external_id: page["id"], name: page["name"], access_token: page["access_token"], by: by)
      instagram = page["instagram_business_account"]&.then do |account|
        keep(network: "instagram", external_id: account["id"], name: account["username"].presence || page["name"], handle: account["username"],
          access_token: page["access_token"], by: by)
      end
      [facebook, instagram].compact
    end
  end

  def publish(delivery)
    channel = delivery.channel
    item = delivery.item
    image = item.image_url
    if channel.network == "instagram"
      raise Calendar::Error, "Instagram posts need an image: add one to the item" unless image

      container, = request(:post, "#{GRAPH}/#{channel.external_id}/media", form: {image_url: image, caption: delivery.text, access_token: channel.access_token})
      published, = request(:post, "#{GRAPH}/#{channel.external_id}/media_publish", form: {creation_id: container["id"], access_token: channel.access_token})
      permalink = get("#{GRAPH}/#{published["id"]}", fields: "permalink", access_token: channel.access_token)["permalink"]
      {external_id: published["id"], external_url: permalink}
    else
      answer, = if image
        request(:post, "#{GRAPH}/#{channel.external_id}/photos", form: {url: image, caption: [delivery.text, item.link].compact_blank.join("\n\n"), access_token: channel.access_token})
      else
        request(:post, "#{GRAPH}/#{channel.external_id}/feed", form: {message: delivery.text, link: item.link, access_token: channel.access_token}.compact_blank)
      end
      id = answer["post_id"] || answer["id"]
      {external_id: id, external_url: "https://www.facebook.com/#{id}"}
    end
  end
end
