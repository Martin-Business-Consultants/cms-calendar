# frozen_string_literal: true

module Calendar
  # The plugin's admin pages: a 404 while it's off, in the core's layout.
  class ApplicationController < ::ApplicationController
    include PluginGated
    plugin :calendar

    private

    # Back to where the action was taken: a path on this site, else the default.
    def back_or(default)
      url = params[:return_to].to_s
      (url.start_with?("/") && !url.start_with?("//")) ? url : default
    end

    def calendar_for(item) = calendar_path(month: item.scheduled_at&.strftime("%Y-%m"), item: item.id)
  end
end
