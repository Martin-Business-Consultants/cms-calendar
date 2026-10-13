# frozen_string_literal: true

module Calendar
  module Items
    # An item scheduled to go out (create), or taken off the schedule (destroy). Going out is publishing.
    class SchedulesController < Calendar::ApplicationController
      requires_capability "calendar:publish", only: [:create, :destroy]

      before_action { @item = Item.find(params[:item_id]) }

      def create
        at = params[:at].presence && Time.zone.parse(params[:at])
        @item.schedule!(at, by: Current.user)
        redirect_to calendar_for(@item), notice: "Scheduled for #{l at, format: :long}"
      rescue Calendar::Error, ArgumentError, ActiveRecord::RecordInvalid => error
        redirect_to calendar_for(@item), alert: error.message
      end

      def destroy
        @item.unschedule!
        redirect_to calendar_for(@item), notice: "Taken off the schedule: it's a draft again"
      end
    end
  end
end
