# frozen_string_literal: true

module Calendar
  module Items
    # Sends an item's posts now (or retries the ones that failed).
    class DispatchesController < Calendar::ApplicationController
      requires_capability "calendar:publish", only: :create

      def create
        item = Item.find(params[:item_id])
        item.update!(scheduled_at: item.scheduled_at || Time.current, state: "sending")
        item.dispatch!
        failed = item.deliveries.reject(&:sent?)
        redirect_to calendar_for(item), (failed.any? ? :alert : :notice) => (failed.any? ? "#{failed.size} didn't go: #{failed.map { "#{it.channel.network_name}: #{it.error}" }.to_sentence}" : "Sent")
      end
    end
  end
end
