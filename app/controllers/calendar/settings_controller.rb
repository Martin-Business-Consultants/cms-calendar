# frozen_string_literal: true

module Calendar
  # Settings › Calendar (Calendar::Settings) and the channels connected.
  class SettingsController < ::Settings::BaseController
    include PluginGated
    plugin :calendar

    requires_capability "settings:read", only: :show
    requires_capability "settings:write", only: :update

    def show
      @settings = Calendar::Settings.current
      @channels = Calendar::Channel.ordered.to_a
    end

    def update
      Calendar::Settings.update(params.require(:calendar).permit(:meta_app_id, :meta_app_secret, :linkedin_app_id, :linkedin_app_secret, :x_app_id, :x_app_secret, :social_guidance))
      Event.record("settings.calendar_updated")
      redirect_to settings_calendar_path, notice: "Saved"
    end
  end
end
