# frozen_string_literal: true

module Calendar
  # Connecting a network: off to its sign-in (new), and back with the code
  # (show), which becomes a channel for each account (every Facebook Page
  # and its Instagram, the LinkedIn profile and Pages, the X account). The
  # Business Profile connects through the Google plugin, without a sign-in.
  class ConnectionsController < ::Settings::BaseController
    include PluginGated
    plugin :calendar

    NETWORKS = {"meta" => Calendar::Networks::Meta, "linkedin" => Calendar::Networks::LinkedIn, "x" => Calendar::Networks::X,
                "google_business" => Calendar::Networks::GoogleBusiness}.freeze

    requires_capability "settings:write", only: [:new, :show]

    before_action { @network = NETWORKS.fetch(params[:network]) { raise ActiveRecord::RecordNotFound }.new }

    def new
      return connected(@network.connect(by: Current.user)) if params[:network] == "google_business"
      return redirect_to(settings_calendar_path, alert: "Add the #{@network.class::NAME} app's ID and secret first") unless @network.ready?

      session[:calendar_oauth] = {"network" => params[:network], "state" => SecureRandom.urlsafe_base64(24), "verifier" => SecureRandom.urlsafe_base64(48)}
      redirect_to @network.authorize_url(redirect_uri: callback, state: session[:calendar_oauth]["state"], verifier: session[:calendar_oauth]["verifier"]), allow_other_host: true
    rescue Calendar::Error => error
      redirect_to settings_calendar_path, alert: error.message
    end

    def show
      started = session.delete(:calendar_oauth).to_h
      return redirect_to(settings_calendar_path, alert: "#{@network.class::NAME} said: #{(params[:error_description] || params[:error]).to_s.humanize}") if params[:error].present?
      unless started["network"] == params[:network] && started["state"].present? && ActiveSupport::SecurityUtils.secure_compare(started["state"], params[:state].to_s)
        return redirect_to(settings_calendar_path, alert: "That sign-in didn't start here; connect again")
      end

      connected(@network.connect(code: params.require(:code), redirect_uri: callback, verifier: started["verifier"], by: Current.user))
    rescue Calendar::Error => error
      redirect_to settings_calendar_path, alert: error.message
    end

    private

    def callback = callback_settings_calendar_url(network: params[:network])

    def connected(channels)
      Event.record("settings.calendar_connected")
      message = channels.any? ? "Connected #{channels.map(&:label).to_sentence}" : "Signed in, but no accounts came back to post to"
      redirect_to settings_calendar_path, (channels.any? ? :notice : :alert) => message
    end
  end
end
