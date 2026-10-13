# frozen_string_literal: true

# The Google Business Profile, through the Google plugin's sign-in (cms-google):
# no app of its own. A post is up to 1,500 characters with a Learn more button
# to the link, and a photo when the item has one.
class Calendar::Networks::GoogleBusiness < Calendar::Networks::Base
  KEY = "google_business"
  NAME = "Google Business Profile"

  def ready? = Calendar.google_business?

  # The profile's location as a channel.
  def connect(by: nil, **)
    raise Calendar::Error, "Connect the Business Profile in Settings › Google first" unless ready?

    settings = ::Google::Settings.current
    [keep(network: "google_business", external_id: settings.business_location, name: settings.business_location_name || "Business Profile", access_token: nil, by: by)]
  end

  def publish(delivery)
    url = ::Google::BusinessProfile.post!(summary: delivery.text, url: delivery.item.link, image_url: delivery.item.image_url)
    {external_id: url, external_url: url.to_s.start_with?("http") ? url : nil}
  rescue ::Google::Error => error
    raise Calendar::Error, error.message
  end
end
