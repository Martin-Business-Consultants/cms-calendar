# frozen_string_literal: true

module Calendar
  module Api
    # POST /api/calendar/items/:id/schedule {"at": ISO time}; DELETE takes it off. Going out is publishing.
    class SchedulesController < BaseController
      requires_capability "calendar:publish", only: [:create, :destroy]

      def create
        @item = Item.find(params[:item_id])
        @item.schedule!(params[:at].presence && Time.zone.parse(params[:at].to_s), by: Current.user)
        render "calendar/api/items/show"
      rescue Calendar::Error, ArgumentError => error
        refuse(error.message)
      end

      def destroy
        @item = Item.find(params[:item_id])
        @item.unschedule!
        render "calendar/api/items/show"
      end
    end
  end
end
