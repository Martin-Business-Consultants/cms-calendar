# frozen_string_literal: true

module Calendar
  module Api
    # GET /api/calendar/channels (tokens are never read back).
    class ChannelsController < BaseController
      requires_capability "calendar:read", only: :index

      def index
        render json: {channels: Channel.ordered.map { {id: it.id, network: it.network, network_name: it.network_name, name: it.name, handle: it.handle, state: it.state, error: it.error, limit: it.limit} }}
      end
    end
  end
end
