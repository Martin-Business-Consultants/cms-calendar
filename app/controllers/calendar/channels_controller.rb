# frozen_string_literal: true

module Calendar
  # A channel forgotten (and its tokens with it).
  class ChannelsController < ::Settings::BaseController
    include PluginGated
    plugin :calendar

    requires_capability "settings:write", only: :destroy

    def destroy
      channel = Calendar::Channel.find(params[:id])
      channel.destroy!
      redirect_to settings_calendar_path, notice: "Removed #{channel.label}"
    end
  end
end
