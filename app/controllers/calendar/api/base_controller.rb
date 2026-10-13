# frozen_string_literal: true

module Calendar
  module Api
    # The plugin's API (/api/calendar…): a 404 while it's off, every action declaring its capability.
    class BaseController < ::Api::BaseController
      include PluginGated
      plugin :calendar
      enforce_authorization

      # Every controller under this one says who may call it, on any core:
      # cores before 1.32.3 turned that off for a plugin's controllers.
      def self.inherited(subclass)
        super
        subclass._skip_authorization = false
      end

      private

      def refuse(message, status: :conflict) = render(json: {error: "refused", message: message}, status: status)
    end
  end
end
